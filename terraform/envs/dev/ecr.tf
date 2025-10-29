resource "aws_ecr_repository" "app" {
  name = var.repo_name

  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle_policy {
    policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 20 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
