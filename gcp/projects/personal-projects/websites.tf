locals {
  websites = {
    euroboros = {
        domain = "euroborosconsulting.com"
        bucket = "euroborosconsulting-com"
    }
    nebed = {
        domain = "nebed.io"
        bucket = "nebed-io"
    }
  }
}

resource "google_storage_bucket" "website" {
  for_each      = local.websites
  name          = each.value.bucket
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

resource "google_storage_bucket_iam_member" "public_read" {
  for_each = local.websites
  bucket   = google_storage_bucket.website[each.key].name
  role     = "roles/storage.objectViewer"
  member   = "allUsers"
}
