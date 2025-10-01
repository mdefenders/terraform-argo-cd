terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    oci = {
      source  = "oracle/oci"
      version = "7.4.0"
    }
  }
}
