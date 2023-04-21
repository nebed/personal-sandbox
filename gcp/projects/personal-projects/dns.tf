locals {
  domains = {
    nebed-io = {
      name = "nebed.io."
      cname = {
        blog         = "hashnode.network."
        gt2btfmznwgo = "gv-xhpxkf75yaju43.dv.googlehosted.com."
      }
      a = {

      }
    }

    euroborosconsulting-com = {
      name = "euroborosconsulting.com."
      cname = {

      }
      a = {

      }
    }

    strataware-io = {
      name = "strataware.io."
      cname = {

      }
      a = {

      }
    }
  }

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
}

output "variable" {
  value = local.cname_records
}

resource "google_dns_managed_zone" "dns" {
  for_each    = local.domains
  name        = each.key
  dns_name    = each.value.name
  description = "${each.value.name} DNS zone"
}


resource "google_dns_record_set" "cname" {
  for_each = { for item in local.cname_records : "${item.name}${item.record}" => item }
  name     = "${each.value.record}.${each.value.domain}"
  type     = "CNAME"
  ttl      = 300

  managed_zone = each.value.name

  rrdatas = [each.value.value]
}

