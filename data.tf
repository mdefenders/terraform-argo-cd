data "oci_containerengine_cluster_kube_config" "kubeconfig" { cluster_id = var.cluster_ocid }

data "external" "oke_token" {
  program = [
    "bash", "-c",
    "oci ce cluster generate-token --cluster-id ${var.cluster_ocid} --region ${var.region} | jq -c '{token: .status.token}'"
  ]
}