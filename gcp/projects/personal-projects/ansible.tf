locals {
  extra_vars = {
    download_cache_dir = "${abspath(path.root)}/.terraform"
    ansible_user       = "uchenebed"
    smtp_creds = toset([
      for item in local.domains : {
        name      = item.name
        smtp_cred = "${data.google_secret_manager_secret.smtp_user["${item}"].value}:${data.google_secret_manager_secret.smtp_pass["${item}"].value}"
      }
    ])

  }

  extra_vars_file = "${abspath(path.root)}/.terraform/ansible-%s.json"
  playbook_path   = "../../../ansible/${var.playbook}"
}

resource "null_resource" "ansible" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    environment = {
      "TMP${self.id}" = jsonencode(local.extra_vars)
    }

    command = "echo $TMP${self.id} > ${format(local.extra_vars_file, self.id)}"
  }

  provisioner "local-exec" {
    environment = {
      ANSIBLE_FORCE_COLOR                = "False"
      ANSIBLE_HOST_KEY_CHECKING          = "False"
      ANSIBLE_USE_PERSISTENT_CONNECTIONS = "True"
    }

    command = <<-EOT
      extra_vars_file="${format(local.extra_vars_file, self.id)}"
      inventory="${google_compute_address.postbox.address},"
      ansible-playbook -v -c paramiko \
        -i "$inventory" -e "@$extra_vars_file" \
        --ssh-extra-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
        "${local.playbook_path}" &&\
      rm -f $extra_vars_file
    EOT
  }

}


data "google_secret_manager_secret" "smtp_user" {
  for_each  = local.domains
  secret_id = each.value.smtp_user_secret
}

data "google_secret_manager_secret" "smtp_pass" {
  for_each  = local.domains
  secret_id = each.value.smtp_password_secret
}

output "secret" {
  value = local.extra_vars.smtp_creds
}
