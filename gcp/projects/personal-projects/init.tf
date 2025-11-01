terraform {
  backend "gcs" {
    bucket = "personal-sandbox-tfstate"
    prefix = "projects/personal-projects"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.62.1"
    }
  }
}

provider "google" {
  project = "personal-projects-384213"
  region  = "us-central1"
}

provider "google-beta" {
  project = "personal-projects-384213"
  region  = "us-central1"
}

provider "helm" {
  kubernetes = {
    host                   = "https://${google_container_cluster.sandbox.endpoint}"
    token                  = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.sandbox.master_auth.0.cluster_ca_certificate)
  }
}

provider "kubernetes" {
    host                   = "https://${google_container_cluster.sandbox.endpoint}"
    token                  = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.sandbox.master_auth.0.cluster_ca_certificate)
}

data "google_project" "current_project" {}

data "google_client_config" "provider" {}