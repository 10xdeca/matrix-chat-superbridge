variable "project" {
  description = "GCP project ID"
  type        = string
  default     = "hashtag-xdeca"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "australia-southeast1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "australia-southeast1-b"
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 30
}

variable "ssh_user" {
  description = "SSH username for the instance"
  type        = string
  default     = "nick"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR ranges allowed to SSH into the instance"
  type        = list(string)
  # No default — forces the operator to explicitly set their IP
}
