terraform {
  backend "s3" {
    bucket       = "oyd-project-terraform-state-2026"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    dynamodb_table = "oyd-project-terraform-locks-2026"
    encrypt      = true
  }
}