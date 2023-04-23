locals {
  extra_vars = {
    download_cache_dir          = "${abspath(path.root)}/.terraform"
    ansible_user                = "uchenebed"
    main_hostname               = "mail.nebed.io"
    mariadb_root_password       = data.google_secret_manager_secret_version.mariadb_root_password.secret_data
    mariadb_postfix_password    = data.google_secret_manager_secret_version.mariadb_postfix_password.secret_data
    postfixadmin_setup_password = data.google_secret_manager_secret_version.postfixadmin_setup_password.secret_data
    domainlist                  = local.domainlist
    postfixadmin_version        = "3.3.13"
    roundcube_version           = "1.6.1"
    roundcube_des_key           = data.google_secret_manager_secret_version.roundcube_des_key.secret_data
  }

  domainlist = [
    for item, value in local.domains : {
      name        = "@${trim(value.name, ".")}"
      smtp_cred   = "${data.google_secret_manager_secret_version.smtp_user["${item}"].secret_data}:${data.google_secret_manager_secret_version.smtp_pass["${item}"].secret_data}"
      mail_domain = "mail.${trim(value.name, ".")}"
      webmaster   = "webmaster@${trim(value.name, ".")}"
    }
    if value.smtp_user_secret != null
  ]

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
