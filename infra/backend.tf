terraform {
  backend "s3" {
    bucket       = "oyd-project-terraform-state-2026"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}