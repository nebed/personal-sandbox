locals {
  domains = {
    nebed-io                = "nebed.io"
    euroborosconsulting-com = "euroborosconsulting.com"
    strataware-io           = "strataware.io"
  }
}

resource "google_dns_managed_zone" "dns" {
  for_each    = local.domains
  name        = each.key
  dns_name    = each.value
  description = "${each.value} DNS zone"
}
