locals {
  domains = {
    nebed-io = {
      name = "nebed.io."
      cname = {
        "blog."         = "hashnode.network."
        "gt2btfmznwgo." = "gv-xhpxkf75yaju43.dv.googlehosted.com."
        "email.mail."   = "mailgun.org."
        "orbyanduche."  = "mail.nebed.io."
        "*.sandbox."           = "sandbox.nebed.io."
      }
      a = {
        "mail." = google_compute_address.postbox.address
        "sandbox." = google_compute_address.k8s_sandbox_ingress.address
      }
      txt = {
        "mailo._domainkey.mail." = "\"k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDBSXGtyNG/OXdOiMKKdRvf4ROo51lfr9p5qhkNbnXZGxy4QpZ3P3YnMYJLx/dRUiMyjOR9jtuZHeAeO4aQZtixO4dZBNx4oCt+5ceKX9RF1qaaBPaDwFRse5mZ4qr7fY54VphrmZlgmtHWW9FtKWv2VOuojo3kxXQgdYcK4Eh4VQIDAQAB\""
        "mail."                  = "\"v=spf1 include:mailgun.org ~all\""
        "_dmarc."                = "\"v=DMARC1;\" \"p=none;\" \"rua=mailto:postmaster@nebed.io;\""
      }
      mx = {
        "" = "0 mail.nebed.io."
      }
      smtp_user_secret     = "mailgun-mail-nebed-io-user"
      smtp_password_secret = "mailgun-mail-nebed-io-password"
    }

    euroborosconsulting-com = {
      name = "euroborosconsulting.com."
      cname = {
        "email.mail." = "mailgun.org."
      }
      a = {
        "mail." = google_compute_address.postbox.address
      }
      txt = {
        "smtp._domainkey.mail." = "\"k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC70s7NGDlPRLs3iBNzdTH2FrjPwx+wfm71hBEqeqDFGHKbzbPD+PxvTmukPQzR1aCUQFB9DMj3/IejXuuqzb1Ec4ztwXLVyfhqOVWjFRzkStXybjoVFERX8OoHKnmc8gSt65RaviLBi1VPrr/1CBuI+fPgY/0ecoXtXo2QEDIUOwIDAQAB\""
        "mail."                 = "\"v=spf1 include:mailgun.org ~all\""
        "_dmarc."               = "\"v=DMARC1;\" \"p=none;\" \"rua=mailto:postmaster@euroborosconsulting.com;\""

      }
      mx = {
        "" = "0 mail.euroborosconsulting.com."
      }
      smtp_user_secret     = "mailgun-mail-euroborosconsulting-com-smtp-user"
      smtp_password_secret = "mailgun-mail-euroborosconsulting-com-smtp-password"
    }

    strataware-io = {
      name = "strataware.io."
      cname = {
        "email.mail." = "mailgun.org."
      }
      a = {
        "mail." = google_compute_address.postbox.address
      }
      txt = {
        "smtp._domainkey.mail." = "\"k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDK+A4KgHeoIaG72mkjCYEpbAbnuekyuyCzBn3/09V07ye9mr1W9jhjOeRseJS4INt62UVL3ds0xbxb2/6jZL84uysruv4Y4TaY0bOAverxeCB38qTK0cgn133Si0LmyJ8tDqUaJ5AluAE4/x/FpmE8W8tqeqkjtl58g4Ae30zQNwIDAQAB\""
        "mail."                 = "\"v=spf1 include:mailgun.org ~all\""
        "_dmarc."               = "\"v=DMARC1;\" \"p=none;\" \"rua=mailto:postmaster@strataware.io;\""
      }
      mx = {
        "" = "0 mail.strataware.io."
      }
      smtp_user_secret     = "mailgun-mail-strataware-io-smtp-user"
      smtp_password_secret = "mailgun-mail-strataware-io-smtp-password"
    }
  }

  mariadb_root_password_secret       = "postbox-mariadb-root-password"
  mariadb_postfix_password_secret    = "postbox-mariadb-postfix-password"
  postfixadmin_setup_password_secret = "postfixadmin-setup-password"
  roundcube_des_key_secret           = "roundcube-des-key"

  cname_records = flatten([
    for dns, content in local.domains : [
      for record, value in content.cname : {
        record = record
        value  = value
        name   = dns
        domain = content.name
      }
    ]
  ])

  txt_records = flatten([
    for dns, content in local.domains : [
      for record, value in content.txt : {
        record = record
        value  = value
        name   = dns
        domain = content.name
      }
    ]
  ])

  a_records = flatten([
    for dns, content in local.domains : [
      for record, value in content.a : {
        record = record
        value  = value
        name   = dns
        domain = content.name
      }
    ]
  ])

  mx_records = flatten([
    for dns, content in local.domains : [
      for record, value in content.mx : {
        record = record
        value  = value
        name   = dns
        domain = content.name
      }
    ]
  ])
}


resource "google_dns_managed_zone" "dns" {
  for_each    = local.domains
  name        = each.key
  dns_name    = each.value.name
  description = "${each.value.name} DNS zone"
}


resource "google_dns_record_set" "cname" {
  for_each = { for item in local.cname_records : "${item.name}${item.record}" => item }
  name     = "${each.value.record}${each.value.domain}"
  type     = "CNAME"
  ttl      = 300

  managed_zone = each.value.name

  rrdatas = [each.value.value]
}

resource "google_dns_record_set" "txt" {
  for_each = { for item in local.txt_records : "${item.name}${item.record}" => item }
  name     = "${each.value.record}${each.value.domain}"
  type     = "TXT"
  ttl      = 300

  managed_zone = each.value.name

  rrdatas = [each.value.value]
}

resource "google_dns_record_set" "a" {
  for_each = { for item in local.a_records : "${item.name}${item.record}" => item }
  name     = "${each.value.record}${each.value.domain}"
  type     = "A"
  ttl      = 300

  managed_zone = each.value.name

  rrdatas = [each.value.value]
}

resource "google_dns_record_set" "mx" {
  for_each = { for item in local.mx_records : "${item.name}${item.record}" => item }
  name     = "${each.value.record}${each.value.domain}"
  type     = "MX"
  ttl      = 300

  managed_zone = each.value.name

  rrdatas = [each.value.value]
}

