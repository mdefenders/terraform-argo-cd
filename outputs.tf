output "oke_token" {
  value     = data.external.oke_token.result["token"]
  sensitive = true
  description = "Kubernetes API token for OKE cluster, safe for use in helm provider."
}

output "kubeconfig_content" {
  value = data.oci_containerengine_cluster_kube_config.kubeconfig.content
  sensitive = true
}