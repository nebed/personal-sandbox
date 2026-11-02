locals {
  extra_vars = {
    download_cache_dir          = "${abspath(path.root)}/.terraform"
    ansible_user                = "uchenebed"
    main_hostname               = "mail.nebed.io"
    mariadb_root_password       = data.google_secret_manager_secret_version.mariadb_root_password.secret_data
    mariadb_postfix_password    = data.google_secret_manager_secret_version.mariadb_postfix_password.secret_data
    postfixadmin_setup_password = data.google_secret_manager_secret_version.postfixadmin_setup_password.secret_data
    domainlist                  = local.domainlist
    postfixadmin_version        = "3.3.16"
    roundcube_version           = "1.6.20"
    roundcube_des_key           = data.google_secret_manager_secret_version.roundcube_des_key.secret_data
    website_domains             = [for k, v in local.websites : v]
    smtp_credentials            = local.smtp_credentials
    certificate_mode            = "auto"
    postbox_data_device         = "/dev/disk/by-id/google-postbox-data"
    postbox_data_mount          = "/mnt/data"
  }

  domainlist = [
    for item, value in local.domains : {
      name        = "@${trim(value.name, ".")}"
      mail_domain = "mail.${trim(value.name, ".")}"
      webmaster   = "webmaster@${trim(value.name, ".")}"
    }
    if value.smtp_user_secret != null
  ]

  smtp_credentials = [
    for item, value in local.domains : {
      name      = "@${trim(value.name, ".")}"
      smtp_cred = "${data.google_secret_manager_secret_version.smtp_user["${item}"].secret_data}:${data.google_secret_manager_secret_version.smtp_pass["${item}"].secret_data}"
    }
    if value.smtp_user_secret != null
  ]

  extra_vars_file = "${abspath(path.root)}/.terraform/ansible-%s.json"
  playbook_path   = "../../../ansible/${var.playbook}"
}

data "archive_file" "ansible_files" {
  type        = "zip"
  source_dir  = "../../../ansible"
  output_path = "${abspath(path.root)}/.terraform/ansible.zip"
}

resource "null_resource" "ansible" {
  depends_on = [
    google_compute_instance.mailserver,
    google_compute_firewall.ssh,
    google_compute_firewall.ssh_deny_public,
    google_compute_firewall.mail-postbox,
    google_compute_firewall.http-postbox,
  ]

  triggers = {
    instance_id = google_compute_instance.mailserver.instance_id
    playbook    = data.archive_file.ansible_files.output_sha256
    extra_vars  = sha256(jsonencode(local.extra_vars))
  }

  # Output is hidden here because the env var holds secrets.
  provisioner "local-exec" {
    environment = {
      "TMP${self.id}" = jsonencode(local.extra_vars)
    }

    command = "umask 077; printf '%s' \"$TMP${self.id}\" > ${format(local.extra_vars_file, self.id)}"
  }

  # Streams Ansible output; secrets are kept out of it with no_log on tasks.
  provisioner "local-exec" {
    environment = {
      ANSIBLE_FORCE_COLOR                = "False"
      ANSIBLE_HOST_KEY_CHECKING          = "False"
      ANSIBLE_USE_PERSISTENT_CONNECTIONS = "True"
    }

    command = <<-EOT
      extra_vars_file="${format(local.extra_vars_file, self.id)}"
      trap 'rm -f "$extra_vars_file"' EXIT
      ansible-playbook -c paramiko \
        -i '${google_compute_address.postbox.address},' -e "@$extra_vars_file" \
        --ssh-extra-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
        "${local.playbook_path}"
    EOT
  }
}


data "google_secret_manager_secret_version" "smtp_user" {
  for_each = { for item, value in local.domains : item => value if value.smtp_user_secret != null }
  secret   = each.value.smtp_user_secret
}

data "google_secret_manager_secret_version" "smtp_pass" {
  for_each = { for item, value in local.domains : item => value if value.smtp_password_secret != null }
  secret   = each.value.smtp_password_secret
}

data "google_secret_manager_secret_version" "mariadb_root_password" {
  secret = local.mariadb_root_password_secret
}

data "google_secret_manager_secret_version" "mariadb_postfix_password" {
  secret = local.mariadb_postfix_password_secret
}

data "google_secret_manager_secret_version" "postfixadmin_setup_password" {
  secret = local.postfixadmin_setup_password_secret
}

data "google_secret_manager_secret_version" "roundcube_des_key" {
  secret = local.roundcube_des_key_secret
}
