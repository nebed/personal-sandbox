resource "google_project_iam_binding" "nginx" {
  project = var.project_id
  role    = "roles/dns.admin"

  members = [
    "principal://iam.googleapis.com/projects/${data.google_project.current_project.number}/locations/global/workloadIdentityPools/${data.google_project.current_project.project_id}.svc.id.goog/subject/ns/cert-manager/sa/cert-manager",
  ]
}
