provider "google" {
  version = "1.4.0"
  project = "${var.project}"
  region  = "${var.region}"
}
# новая веделенная сеть
resource "google_compute_subnetwork" "my_network_subnet" {
  name          = "my-subnetwork"
  ip_cidr_range = "10.10.10.0/24"
  region        = "europe-west1"
  network       = "${google_compute_network.my_network.self_link}"
}
resource "google_compute_network" "my_network" {
  name = "my-network"
  auto_create_subnetworks = false
}
# виртуалка с приложением в Docker
resource "google_compute_instance" "docker-app" {
  name         = "docker-app"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["docker-app"]

  boot_disk {
    initialize_params {
      image = "${var.disk_image}"
    }
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.my_network_subnet.self_link}"
    network_ip = "10.10.10.100"
    access_config = {
      nat_ip = ""
    }
  }
  
  metadata {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
  depends_on = ["google_compute_subnetwork.my_network_subnet"]
}
resource "google_compute_firewall" "firewall_app" {
  name = "allow-app-default"

  # Название сети, в которой действует правило
  network = "${google_compute_network.my_network.self_link}"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  # Каким адресам разрешаем доступ (мой "белый")
  source_ranges = ["178.34.162.207/32"]

  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["docker-app"]
  depends_on = ["google_compute_network.my_network"]
}

# виртуалка с PostgreSQL
resource "google_compute_instance" "postgresql-db" {
  name         = "postgresql-db"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  tags         = ["postgresql-db"]
  boot_disk {
    initialize_params {
      image = "${var.disk_image}"
    }
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.my_network_subnet.self_link}"
    network_ip = "10.10.10.10"

    access_config = {
      nat_ip = "${google_compute_address.db_ip.address}"
    }
  }

  metadata {
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }
  depends_on = ["google_compute_subnetwork.my_network_subnet"]
}

resource "google_compute_firewall" "firewall_postgresql" {
  name = "allow-postgresql-default"

  # Название сети, в которой действует правило
  network = "${google_compute_network.my_network.self_link}"

  # Какой доступ разрешить
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  # Каким адресам разрешаем доступ
  source_ranges = ["0.0.0.0/0"]

  # Правило применимо для инстансов с перечисленными тэгами
  target_tags = ["postgresql-db"]
  depends_on = ["google_compute_network.my_network"]
}
resource "google_compute_address" "db_ip" {
  name = "postgresql-db-ip"
}

# ansible inventory file
resource "null_resource" "ansible-provision" {
  
  provisioner "local-exec" {
    command = "echo [all:vars] > hosts"
  }

  provisioner "local-exec" {
    command = "echo ansible_python_interpreter = /usr/bin/python3 >> hosts"
  }

  provisioner "local-exec" {
    command = "echo [hosts] >> hosts"
  }

  provisioner "local-exec" {
    command = "echo '${google_compute_instance.docker-app.name} ansible_host=${google_compute_instance.docker-app.network_interface.0.access_config.0.assigned_nat_ip} ansible_ssh_user=appuser' >> hosts"
    
  }

  provisioner "local-exec" {
    command = "echo '${google_compute_instance.postgresql-db.name} ansible_host=${google_compute_instance.postgresql-db.network_interface.0.access_config.0.assigned_nat_ip} ansible_ssh_user=appuser' >> hosts"
    
  }
  depends_on = ["google_compute_instance.docker-app","google_compute_firewall.firewall_postgresql"]

  provisioner "local-exec" {
    command = "cat hosts.example >> hosts"
  }
}
