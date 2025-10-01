# Terraform Argo CD Module

A lightweight Terraform module to deploy [Argo CD](https://argo-cd.readthedocs.io/) (and optionally a companion AppSets
Helm chart) into an existing Oracle Cloud Infrastructure (OCI) OKE Kubernetes cluster using the Helm provider.

---

## What This Module Does

1. Retrieves an OKE cluster kubeconfig and short‑lived access token (via `oci` CLI + `jq`).
2. Installs the official `argo-cd` Helm chart into namespace `argocd`.
3. Optionally installs a custom `argo-appsets` Helm chart (your organizational AppSet definitions) when
   `deploy_appsets = true`.
4. Templates a provided `values.yaml` with selected variables to drive the AppSets chart.

## Features

- Atomic Helm installs (will roll back on failure)
- Explicit chart version pinning for reproducibility
- Minimal surface area: only Argo CD + optional AppSets
- Token + kubeconfig outputs (sensitive) for downstream Helm or Kubernetes provider usage
- Simple toggle (`deploy_appsets`) to include/exclude organizational AppSets

## Architecture / Flow

```
Terraform ─┬─(data.oci_containerengine_cluster_kube_config)──> OKE kubeconfig
           └─(data.external.oke_token -> oci cli + jq)──────> Short-lived auth token

Helm Provider (configured using kubeconfig/token) ──> Install argo-cd chart
                                                     (optional) Install argo-appsets chart
```

## Prerequisites

You need the following available in the execution environment where `terraform apply` runs:

- Terraform (no `required_version` pinned here; commonly 1.5+ / 1.6+ recommended)
- OCI CLI (`oci`) authenticated/configured with permissions to:
    - Read the target OKE cluster (`containerengine_cluster`)
    - Generate OKE cluster tokens
- `jq` (used to parse JSON token output)
- Network egress to reach:
    - `https://argoproj.github.io/argo-helm`
    - `https://mdefenders.github.io/helmcharts` (only if `deploy_appsets = true`)
- An existing OKE cluster OCID

### Required IAM (High Level)

The principal (user/group/workload) running Terraform must have policies allowing:

- `inspect cluster-family` and `read cluster` on the target compartment / cluster

## Quick Start

```hcl
module "argocd" {
  source = "github.com/mdefenders/terraform-argo-cd"  # or relative path if vendored

  cluster_ocid = var.cluster_ocid
  region       = var.region
  argocd_chart_version = "8.2.5" # optional override
  deploy_appsets = true

  # AppSets-related (only needed if deploy_appsets=true)
  appset_name   = "platform-apps"
  github_org    = "my-org"
  chart_repo = "my-org/helm-charts"   # GitHub repo path
  chart_name    = "my-platform"
  chart_version = "1.2.3"
}
```

Then:

```bash
terraform init
terraform plan
terraform apply
```

## Examples

### Minimal (Argo CD only)

```hcl
module "argocd" {
  source       = "github.com/mdefenders/terraform-argo-cd"
  cluster_ocid = var.cluster_ocid
  region       = var.region
  # deploy_appsets remains default false
}
```

### With AppSets

```hcl
module "argocd" {
  source                = "github.com/mdefenders/terraform-argo-cd"
  cluster_ocid          = var.cluster_ocid
  region                = var.region
  deploy_appsets        = true
  appset_name           = "platform-apps"
  github_org            = "my-github-org"
  chart_repo            = "my-github-org/helm-charts"
  chart_name            = "platform"
  chart_version         = "0.4.0"
  argocd_chart_version  = "8.2.5"
  appsets_chart_version = "8.2.5"
}
```

## Input Variables

| Name                  | Type   | Default | Required                          | Description                                                        |
|-----------------------|--------|---------|-----------------------------------|--------------------------------------------------------------------|
| argocd_chart_version  | string | "8.2.5" | No                                | Version of official Argo CD Helm chart.                            |
| appsets_chart_version | string | "8.2.5" | No                                | Version of the custom AppSets chart.                               |
| appset_name           | string | n/a     | Conditionally (if deploy_appsets) | Name of the AppSet set/group.                                      |
| github_org            | string | n/a     | Conditionally                     | GitHub organization hosting repos.                                 |
| chart_repo            | string | n/a     | Conditionally                     | GitHub repository path containing the Helm charts (e.g. org/repo). |
| chart_name            | string | n/a     | Conditionally                     | Name of the Helm chart to deploy via AppSets.                      |
| chart_version         | string | n/a     | Conditionally                     | Version of the Helm chart referenced by the AppSet.                |
| cluster_ocid          | string | n/a     | Yes                               | OCID of target OKE cluster.                                        |
| region                | string | n/a     | Yes                               | OCI region of the OKE cluster (used by OCI CLI token generation).  |
| deploy_appsets        | bool   | false   | No                                | Toggle to install the `argo-appsets` chart.                        |

Notes:

- When `deploy_appsets = true`, all AppSets-related variables become required.
- No validation blocks are present yet; misconfiguration will surface as Helm template/apply failures.

## Outputs

| Name               | Sensitive | Description                                                              |
|--------------------|-----------|--------------------------------------------------------------------------|
| oke_token          | Yes       | Short-lived Kubernetes API token (from `oci ce cluster generate-token`). |
| kubeconfig_content | Yes       | Full kubeconfig content for the OKE cluster.                             |

These outputs enable you to chain additional Helm or Kubernetes provider operations without re-fetching credentials.

## Customization

### Overriding Chart Values for Argo CD

You can extend this module to pass additional `values` to the `helm_release.argocd` resource by forking or wrapping the
module and adding a variable (e.g. `argocd_extra_values`). Currently it's pinned to defaults from upstream chart.

### Modifying AppSets Template

The `values.yaml` file in the module root is processed with `templatefile`, exposing these placeholders under `var.*`:

- `${var.appset_name}`
- `${var.github_org}`
- `${var.chart_repo}`
- `${var.chart_name}`
- `${var.chart_version}`

If you need more dynamic substitution, you can:

1. Copy the module locally
2. Add more variables to `variables.tf`
3. Reference them inside `values.yaml`

### Filters

Current filter example (in `values.yaml`) selects feature branches with repositories ending in `-gitops` containing a
specific path. Adjust to match your branching / repo naming strategy.

## Working With AppSets

The AppSets Helm chart is assumed to:

- Create Argo CD ApplicationSets based on repository scanning
- Use the templated variables to locate Helm chart definitions and values files

After deployment, confirm ApplicationSets via:

```bash
kubectl -n argocd get applicationsets.argoproj.io
```

(Use the kubeconfig and token from outputs if your local context differs.)

## Operational Notes

- Helm releases use `atomic = true` ensuring rollback on failure.
- Timeout is set to 600s; adjust in a fork if you have slower clusters.
- Namespace `argocd` is created automatically if missing.
- No explicit dependency is declared between the external token data and the Helm provider; ensure your Helm provider
  configuration (not shown in this module) consumes the outputs when chaining modules.

## Troubleshooting

| Symptom                      | Possible Cause                               | Resolution                                                                      |
|------------------------------|----------------------------------------------|---------------------------------------------------------------------------------|
| `external` data source fails | `oci` CLI not installed or not authenticated | Install/configure OCI CLI; verify `oci ce cluster get --cluster-id <id>` works. |
| `jq: command not found`      | Missing jq                                   | Install jq (`brew install jq` on macOS).                                        |
| Helm install timeout         | Cluster not ready / webhooks delaying pods   | Increase `timeout` or investigate pod events.                                   |
| Argo CD pods CrashLoop       | Upstream chart values need tuning            | Fork module and add custom `values` override.                                   |
| AppSets not created          | Filters exclude repos / branches             | Adjust filters in `values.yaml` to match your naming conventions.               |

## Upgrade Notes

When updating chart versions:

- Review upstream Argo CD chart CHANGELOG for breaking values changes
- Apply in a non‑prod environment first
- Because `atomic` is true, partial failures roll back; inspect `helm list -n argocd` and events if apply fails

## License

This project is licensed under the MIT License. See `LICENSE.md` for details.

## Contributing

1. Fork / branch
2. Make changes with minimal diff
3. Include rationale in PR description
4. Keep provider and chart versions explicit

## Security

No runtime credentials are stored in state except the kubeconfig and token outputs (marked sensitive). Consider using a
remote backend with encryption at rest.

---
Happy GitOps-ing! If you find this useful, a star is always appreciated.

