variable "argocd_chart_version" {
  description = "The Helm release for ArgoCD."
  type        = string
  default     = "8.2.5"
}
variable "appsets_chart_version" {
  description = "The Helm release for AppSets."
  type        = string
  default     = "8.2.5"
}
variable "appset_name" {
  description = "The name of the ArgoCD AppSet to create."
  type        = string
}
variable "github_org" {
  description = "The GitHub organization where the repo is located."
  type        = string
}
variable "chart_repo" {
  description = "The GitHub repository where the Helm charts are located."
  type        = string
}
variable "chart_name" {
  description = "The name of the Helm chart to deploy."
  type        = string
}
variable "chart_version" {
  description = "The version of the Helm chart to deploy."
  type        = string
}
variable "cluster_ocid" {
  description = "The OCID of the OKE cluster where ArgoCD will be deployed."
  type        = string
}
variable "region" {
  description = "The region to deploy resources in"
  type        = string
}
variable "deploy_appsets" {
  description = "Whether to deploy ArgoCD AppSets"
  type        = bool
  default     = false
}
