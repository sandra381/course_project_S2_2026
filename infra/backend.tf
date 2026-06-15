terraform {
  backend "s3" {
    # Los valores se inyectan en cada CI run via:
    # terraform init -backend-config=envs/dev/backend-dev.hcl
    # terraform init -backend-config=envs/staging/backend-staging.hcl
  }
}