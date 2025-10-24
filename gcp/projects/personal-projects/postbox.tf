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

  local_ip_file  = "${abspath(path.root)}/.terraform/ip.txt"
  public_ssh_key = "${abspath(path.root)}/files/id_rsa.pub"

}

data "google_compute_network" "default" {
  name = "default"
}

data "google_compute_subnetwork" "default" {
  name   = "default"
  region = "us-central1"
}

resource "google_compute_address" "postbox" {
  name         = "postbox-public-ip"
  network_tier = "STANDARD"
}

resource "google_compute_address" "k8s_sandbox_ingress" {
  name         = "k8s-sandbox-public-ip"
  network_tier = "STANDARD"
}

resource "google_compute_instance" "mailserver" {
  name         = local.vm_config.name
  machine_type = local.vm_config.size
  zone         = local.vm_config.zone

  tags = local.vm_config.network_tags

  boot_disk {
    initialize_params {
      image = local.vm_config.image
      size  = local.vm_config.disk_size
      type  = local.vm_config.disk_type
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.default.self_link

    access_config {
      nat_ip = google_compute_address.postbox.address
    }
  }

  metadata = {
    ssh-keys = data.local_file.ssh_key.content
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

resource "google_compute_firewall" "mail-postbox" {
  name        = "allow-mail-traffic-from-world"
  network     = data.google_compute_network.default.self_link
  description = "Firewall rule to allow mail traffic to instance"

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["25", "143", "465", "587", "993"]
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

  source_ranges = [trimspace(data.local_file.local_ip.content)]
  target_tags   = local.vm_config.network_tags
}

resource "null_resource" "local_ip" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {

    command = "echo \"$(curl https://ipinfo.io/ip)/32\" > ${local.local_ip_file}"
  }
}

data "local_file" "local_ip" {
  filename   = local.local_ip_file
  depends_on = [null_resource.local_ip]
}

data "local_file" "ssh_key" {
  filename = local.public_ssh_key
}
