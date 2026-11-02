locals {
  vm_config = {
    name         = "postbox"
    size         = "e2-micro"
    zone         = "us-central1-a"
    network_tags = ["postbox"]
    disk_size    = 10
    image        = "debian-cloud/debian-13"
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

# Data is independent of the replaceable VM boot disk. Never destroy it as part
# of routine postbox updates.
resource "google_compute_disk" "postbox_data" {
  name = "postbox-data"
  zone = local.vm_config.zone
  type = "pd-standard"
  size = 10

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_instance" "mailserver" {
  name         = local.vm_config.name
  machine_type = local.vm_config.size
  zone         = local.vm_config.zone
  tags         = local.vm_config.network_tags

  boot_disk {
    initialize_params {
      image = local.vm_config.image
      size  = local.vm_config.disk_size
      type  = local.vm_config.disk_type
    }
  }

  attached_disk {
    source      = google_compute_disk.postbox_data.self_link
    device_name = "postbox-data"
    mode        = "READ_WRITE"
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.default.self_link

    access_config {
      nat_ip       = google_compute_address.postbox.address
      network_tier = "STANDARD"
    }
  }

  desired_status            = "RUNNING"
  allow_stopping_for_update = true

  metadata = {
    ssh-keys = data.local_file.ssh_key.content
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_firewall" "http-postbox" {
  name        = "allow-http-https-from-world"
  network     = data.google_compute_network.default.self_link
  description = "Allow HTTP and HTTPS to the postbox web endpoints"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = local.vm_config.network_tags
}

# Public mail policy: inbound SMTP (25), IMAP (143/993), and submission
# (465/587). This rule already followed the production tag during cutover.
resource "google_compute_firewall" "mail-postbox" {
  name        = "allow-mail-traffic-from-world"
  network     = data.google_compute_network.default.self_link
  description = "Allow public SMTP, IMAP and message submission to the postbox"
  direction   = "INGRESS"

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
  description = "Allow SSH from the current operator IPv4 address"
  direction   = "INGRESS"
  priority    = 900

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [trimspace(data.local_file.local_ip.content)]
  target_tags   = local.vm_config.network_tags
}

resource "google_compute_firewall" "ssh_deny_public" {
  name        = "deny-public-ssh-to-postbox"
  network     = data.google_compute_network.default.self_link
  description = "Prevent default network rules from bypassing the postbox SSH allowlist"
  direction   = "INGRESS"
  priority    = 1000

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = local.vm_config.network_tags
}

resource "null_resource" "local_ip" {
  triggers = {
    always_run = timestamp()
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

output "postbox_ip" {
  description = "Production postbox public IP."
  value       = google_compute_address.postbox.address
}

output "postbox_instance_name" {
  description = "Production postbox GCE instance name."
  value       = google_compute_instance.mailserver.name
}
