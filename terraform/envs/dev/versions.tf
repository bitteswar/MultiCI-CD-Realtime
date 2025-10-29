terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = ">= 4.0"
    }
# add helm/kubernetes providers if you want Terraform to manage Helm releases directly

    helm = {
      source = "hashicorp/helm"
      version = ">= 2.7"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.11"

    }

  }
}