resource "google_container_cluster" "sandbox" {
  name     = "sandbox"
  location = "us-central1-c"

  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode         = "ROUTES"
  release_channel {
    channel = "REGULAR"
  }
  subnetwork = data.google_compute_subnetwork.default.self_link

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }
  logging_service = "none"
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }
  monitoring_service = "none"

  workload_identity_config {
    workload_pool = "${data.google_project.current_project.project_id}.svc.id.goog"
  }

}


resource "google_container_node_pool" "workload" {
  name_prefix = "workload-"
  cluster    = google_container_cluster.sandbox.id
  node_count = 2

  management {
    auto_repair = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 20
    disk_type = "pd-balanced"
    image_type = "UBUNTU_CONTAINERD"
    spot = true
    resource_labels  = {
       "goog-gke-node-pool-provisioning-model" = "spot"
    }
  }

  lifecycle {
    ignore_changes = [ node_config[0].kubelet_config ]
  }
}

resource "google_container_node_pool" "bitcoin" {
  name_prefix = "bitcoin-"
  cluster    = google_container_cluster.sandbox.id
  node_count = 1

  management {
    auto_repair = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "c2d-standard-4"
    disk_size_gb = 20
    disk_type = "pd-balanced"
    image_type = "UBUNTU_CONTAINERD"
    spot = true
    resource_labels  = {
       "goog-gke-node-pool-provisioning-model" = "spot"
    }
  }

  lifecycle {
    ignore_changes = [ node_config[0].kubelet_config ]
  }
}
