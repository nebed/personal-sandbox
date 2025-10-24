locals {
    environment_map = {
        "k8s-dev"    = "{dev,hotfix,staging,lab}"
        "k8s-eu-prod" = "eu-prod"
        "k8s-us-prod"    = "us-prod"
        "k8s-infra"  = "infra"
    } 
}

provider "helm" {
  kubernetes = {
    host                   = "https://${google_container_cluster.sandbox.endpoint}"
    token                  = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.sandbox.master_auth.0.cluster_ca_certificate)
  }
}

provider "kubernetes" {
    host                   = "https://${google_container_cluster.sandbox.endpoint}"
    token                  = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.sandbox.master_auth.0.cluster_ca_certificate)
}


resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.17.1"
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
      project_id  = var.project_id
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

  name             = "ingress-nginx-public"
  namespace        = "ingress-nginx-public"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.2.1"
  create_namespace = true

  # https://github.com/helm/helm/issues/7811
  atomic          = true
  cleanup_on_fail = true

  values = [
    templatefile("${path.module}/templates/ingress-nginx/values.yaml", {
      class_resource_name          = "ingress-nginx-public"
      controller_value             = "k8s.io/ingress-nginx-public"
      load_balancer_ip             = google_compute_address.k8s_sandbox_ingress.address
      default_tls_certificate      = "ingress-nginx-public/default-public-ingress-tls"
    }),
  ]

    depends_on = [kubernetes_manifest.public_nebed_io_cert]   
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.6.8"
  create_namespace = true
  values = [
    templatefile("${path.module}/templates/argocd/values.yaml", {
      dex_github_client_id = data.google_secret_manager_secret_version.argocd_dex_github_id.secret_data
    }),
  ]

}

resource "helm_release" "root-registry-provisioner" {
  name             = "root-registry-provisioner"
  namespace        = "argocd"
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