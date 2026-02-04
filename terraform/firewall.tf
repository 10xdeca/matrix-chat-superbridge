# HTTP (for ACME challenges / redirect to HTTPS)
resource "google_compute_firewall" "matrix_http" {
  name    = "matrix-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["matrix-server"]
}

# HTTPS (Matrix client API, Element, Synapse Admin)
resource "google_compute_firewall" "matrix_https" {
  name    = "matrix-allow-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["matrix-server"]
}

# Matrix federation
resource "google_compute_firewall" "matrix_federation" {
  name    = "matrix-allow-federation"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8448"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["matrix-server"]
}

# COTURN TURN/STUN (voice/video calls)
resource "google_compute_firewall" "matrix_coturn" {
  name    = "matrix-allow-coturn"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3478", "5349"]
  }

  allow {
    protocol = "udp"
    ports    = ["3478", "5349", "49152-49172"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["matrix-server"]
}

# SSH (restricted — update source_ranges to your IP for production)
resource "google_compute_firewall" "matrix_ssh" {
  name    = "matrix-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["matrix-server"]
}
