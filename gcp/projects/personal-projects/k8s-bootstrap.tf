locals {
    cert_manager = {
        name    = "cert-manager"
        namespace = "cert-manager"
        version = "v1.17.1"
        chart   = "cert-manager"
        repo    = "https://charts.jetstack.io"
    }
    nginx = {
        name    = "ingress-nginx-public"
        namespace = "ingress-nginx-public"
        version = "4.2.1"
        chart   = "ingress-nginx"
        repo    = "https://kubernetes.github.io/ingress-nginx"
    }
    argocd = {
        name    = "argocd"
        namespace = "argocd"
        version = "7.6.8"
        chart   = "argo-cd"
        repo    = "https://argoproj.github.io/argo-helm"
    }
}

# Configure IAM binding to allow cert-manager's serviceaccount to manage DNS records in GCP

resource "google_project_iam_binding" "cert_manager_dns_admin" {
  project = data.google_project.current_project.project_id
  role    = "roles/dns.admin"

  members = [
    "principal://iam.googleapis.com/projects/${data.google_project.current_project.number}/locations/global/workloadIdentityPools/${data.google_project.current_project.project_id}.svc.id.goog/subject/ns/cert-manager/sa/cert-manager",
  ]
}

resource "helm_release" "cert_manager" {
  name             = local.cert_manager.name
  namespace        = local.cert_manager.namespace
  repository       = local.cert_manager.repo
  chart            = local.cert_manager.chart
  version          = local.cert_manager.version
  create_namespace = true

  # https://github.com/helm/helm/issues/7811
  atomic          = true
  cleanup_on_fail = true

  values = [
    templatefile("${path.module}/templates/cert-manager/values.yaml", {
    })
  ]
}

resource "kubernetes_manifest" "letsencrypt_clouddns_clusterissuer" {

  manifest =  yamldecode(templatefile(
    "${path.module}/templates/cert-manager/manifests/gcpissuer.yaml", {
      kind        = "ClusterIssuer"
      server      = "https://acme-v02.api.letsencrypt.org/directory"
      email       = "me@nebed.io"
      name        = "clouddns-clusterissuer"
      project_id  = data.google_project.current_project.project_id
      secret_name = "letsencrypt-clouddns-issuer-account-key"
  }))

  depends_on = [ helm_release.cert_manager ]
}

resource "kubernetes_manifest" "public_nebed_io_cert" {

  manifest = yamldecode(templatefile("${path.module}/templates/cert-manager/manifests/wildcard-cert.yaml", {
    domain = "sandbox.nebed.io"
    issuer = "clouddns-clusterissuer"
    name   = "default-public-ingress-tls"
    namespace = "ingress-nginx-public"
  }))

  depends_on = [kubernetes_manifest.letsencrypt_clouddns_clusterissuer]
}

resource "helm_release" "nginx_ingress_public" {

  name             = local.nginx.name
  namespace        = local.nginx.namespace
  repository       = local.nginx.repo
  chart            = local.nginx.chart
  version          = local.nginx.version
  create_namespace = true

  # https://github.com/helm/helm/issues/7811
  atomic          = true
  cleanup_on_fail = true

  values = [
    templatefile("${path.module}/templates/ingress-nginx/values.yaml", {
      class_resource_name          = local.nginx.name
      controller_value             = "k8s.io/${local.nginx.name}"
      load_balancer_ip             = google_compute_address.k8s_sandbox_ingress.address
      default_tls_certificate      = "${local.nginx.namespace}/default-public-ingress-tls"
    }),
  ]

    depends_on = [kubernetes_manifest.public_nebed_io_cert]   
}

resource "helm_release" "argocd" {
  name             = local.argocd.name
  namespace        = local.argocd.namespace
  repository       = local.argocd.repo
  chart            = local.argocd.chart
  version          = local.argocd.version
  create_namespace = true
  values = [
    templatefile("${path.module}/templates/argocd/values.yaml", {
      dex_github_client_id = data.google_secret_manager_secret_version.argocd_dex_github_id.secret_data
    }),
  ]

}

resource "helm_release" "root-registry-provisioner" {
  name             = "root-registry-provisioner"
  namespace        = local.argocd.namespace
  repository       = "${path.module}/charts"
  chart            = "root-registry-provisioner"
  dependency_update = true

  values = [
    yamlencode({
      environment = "sandbox"
    }),
  ]

  depends_on = [helm_release.argocd]
}


data "google_secret_manager_secret_version" "argocd_dex_github_id" {
  secret = "argocd-sandbox-github-client-id"
}

data "google_secret_manager_secret_version" "argocd_dex_github_secret" {
  secret = "argocd-sandbox-github-client-secret"
}

data "google_secret_manager_secret_version" "argocd_repo_git_app_id" {
  secret = "argocd-sandbox-git-app-id"
}

data "google_secret_manager_secret_version" "argocd_repo_git_app_installation_id" {
  secret = "argocd-sandbox-git-app-installation-id"
}

data "google_secret_manager_secret_version" "argocd_repo_git_private_key" {
  secret = "argocd-sandbox-git-private-key"
}

resource "kubernetes_secret" "argocd_dex_secret" {

  metadata {
    name = "argocd-dex"
    namespace = "argocd"
    labels = {
       "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "dex.github.clientSecret" = data.google_secret_manager_secret_version.argocd_dex_github_secret.secret_data
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret" "argocd_git_secret" {
  metadata {
    name = "argocd-repo-secret-github-com"
    namespace = "argocd"
    labels = {
       "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }

  data = {
    type = "git"
    url = "https://github.com/nebed/"
    githubAppID = data.google_secret_manager_secret_version.argocd_repo_git_app_id.secret_data
    githubAppInstallationID = data.google_secret_manager_secret_version.argocd_repo_git_app_installation_id.secret_data
    githubAppPrivateKey = data.google_secret_manager_secret_version.argocd_repo_git_private_key.secret_data
  }

  depends_on = [helm_release.argocd]
}