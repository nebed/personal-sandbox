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
  region  = "us-central1-a"
}
