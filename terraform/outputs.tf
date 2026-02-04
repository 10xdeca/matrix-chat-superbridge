output "external_ip" {
  description = "Static external IP address of the Matrix server"
  value       = google_compute_address.matrix.address
}

output "sslip_domain" {
  description = "sslip.io domain for the server (use as matrix_domain base)"
  value       = "${replace(google_compute_address.matrix.address, ".", "-")}.sslip.io"
}

output "matrix_url" {
  description = "Matrix homeserver URL"
  value       = "https://matrix.${replace(google_compute_address.matrix.address, ".", "-")}.sslip.io"
}

output "element_url" {
  description = "Element Web client URL"
  value       = "https://element.${replace(google_compute_address.matrix.address, ".", "-")}.sslip.io"
}

output "ansible_host_line" {
  description = "Line to use in Ansible inventory hosts-production"
  value       = "matrix.${replace(google_compute_address.matrix.address, ".", "-")}.sslip.io ansible_host=${google_compute_address.matrix.address} ansible_port=22 ansible_ssh_user=${var.ssh_user} ansible_become=true ansible_become_user=root ansible_python_interpreter=/usr/bin/python3 ansible_ssh_private_key_file=~/.ssh/id_ed25519"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh ${var.ssh_user}@${google_compute_address.matrix.address}"
}
