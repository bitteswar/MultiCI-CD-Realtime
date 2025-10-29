variable "aws_region" {
    description = "AWS region"
    type        = string
    default     = "us-east-1"
 
}

variable "repo_name" {
    description = "ECR repository name"
    type        = string
    default     = "sample-app"

}

variable "cluster_name" {
  description = "EKS cluster name (optional if creating EKS)"
  type        = string
  default     = "sampleapp-eks-dev"
}

variable "create_eks" {
  description = "If true, Terraform will create an EKS cluster (can be slow)"
  type        = bool
  default     = false
}

