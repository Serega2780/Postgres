variable project {
  description = "infra-219518"
  default = "infra-219518"
}

variable region {
  description = "Region"
  default     = "europe-west1"
}

variable zone {
  description = "Zone"
  default     = "europe-west1-b"
}

variable public_key_path {
  description = "Path to the public key used for ssh access"
}

variable private_key_path {
  description = "Path to the private key used by provisioners"
}

variable disk_image {
  description = "ubuntu-1604-lts"
}
