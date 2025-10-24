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

data "google_project" "current_project" {}

data "google_client_config" "provider" {}