resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  create_namespace = true
  atomic           = true
  timeout          = 600
}

resource "helm_release" "appsets" {
  count            = var.deploy_appsets ? 1 : 0
  name             = "argo-appsets"
  namespace        = "argocd"
  repository       = "https://mdefenders.github.io/helmcharts"
  chart            = "argo-appsets"
  version          = var.appsets_chart_version
  create_namespace = true
  # Use templatefile so ${var.*} placeholders in values.yaml are interpolated
  values = [templatefile("${path.module}/values.yaml", {
    var = {
      appset_name   = var.appset_name
      github_org    = var.github_org
      chart_repo    = var.chart_repo
      chart_name    = var.chart_name
      chart_version = var.chart_version
    }
  })]
  atomic     = true
  depends_on = [helm_release.argocd]
}
