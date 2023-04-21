locals {

  vm_config = {
    name         = "postbox"
    size         = "e2-micro"
    zone         = "us-central1-a"
    network_tags = ["postbox"]
    disk_size    = "10"
    image        = "debian-cloud/debian-11"
    disk_type    = "pd-standard"
  }

  local_ip_file = "${abspath(path.root)}/.terraform/ip.txt"

}

data "google_compute_network" "default" {
  name = "default"
}

data "google_compute_subnetwork" "default" {
  name   = "default"
  region = "us-central1"
}

resource "google_compute_address" "postbox" {
  name = "postbox-public-ip"
}

resource "google_compute_instance" "mailserver" {
  name         = local.vm_config.name
  machine_type = local.vm_config.size
  zone         = local.vm_config.zone

  tags = local.vm_config.tags

  boot_disk {
    initialize_params {
      image = local.vm_config.image
      size  = local.vm_config.disk_size
      type  = local.vm_config.disk_type
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "SCSI"
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.default.self_link

    access_config {
      nat_ip = google_compute_address.postbox.address
    }
  }

}

resource "google_compute_firewall" "http-postbox" {
  name        = "allow-http-https-from-world"
  network     = data.google_compute_network.default.self_link
  description = "Firewall rule to allow http & https traffic to instance"

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = local.vm_config.network_tags
}

resource "google_compute_firewall" "ssh" {
  name        = "allow-ssh-from-local-machine"
  network     = data.google_compute_network.default.self_link
  description = "Firewall rule to allow SSH from local machine"

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [data.local_ip_file.content]
  target_tags   = local.vm_config.network_tags
}

resource "null_resource" "local_ip" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {

    command = "dig +short myip.opendns.com @resolver1.opendns.com > ${local.local_ip_file}"
  }
}

data "local_file" "local_ip" {
  filename   = local.local_ip_file
  depends_on = ["null_resource.local_ip"]
}
