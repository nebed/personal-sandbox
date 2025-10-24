variable "playbook" {
  default = "mail.yml"
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default = "personal-projects-384213"
}
