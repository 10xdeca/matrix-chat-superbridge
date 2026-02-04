terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

# Static external IP
resource "google_compute_address" "matrix" {
  name   = "matrix-superbridge-ip"
  region = var.region
}

# Service account for the instance
resource "google_service_account" "matrix" {
  account_id   = "matrix-superbridge"
  display_name = "Matrix Superbridge VM"
}

# GCE instance
resource "google_compute_instance" "matrix" {
  name         = "matrix-superbridge"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["matrix-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.disk_size_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.matrix.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(pathexpand(var.ssh_public_key_path))}"
  }

  service_account {
    email  = google_service_account.matrix.email
    scopes = ["compute-ro", "logging-write", "monitoring-write"]
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  lifecycle {
    ignore_changes = [metadata["ssh-keys"]]
  }
}
