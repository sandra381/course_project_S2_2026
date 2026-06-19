# ─── COMPUTE ROLE (Lambda API) ────────────────────────────────────────────────
output "lambda_api_role_arn" {
  description = "ARN of the Lambda API execution role. Consumed by infra/modules/compute/."
  value       = aws_iam_role.lambda_api.arn
}

output "lambda_api_role_name" {
  description = "Name of the Lambda API execution role."
  value       = aws_iam_role.lambda_api.name
}

# ─── ASYNC CONSUMER ROLE (Lambda Worker) ─────────────────────────────────────
output "lambda_worker_role_arn" {
  description = "ARN of the Lambda Worker execution role (async consumer). Consumed by infra/modules/compute/."
  value       = aws_iam_role.lambda_worker.arn
}

output "lambda_worker_role_name" {
  description = "Name of the Lambda Worker execution role."
  value       = aws_iam_role.lambda_worker.name
}

# ─── CLEANUP EXECUTION ROLE (Lambda Cleanup) ──────────────────────────────────
output "lambda_cleanup_role_arn" {
  description = "ARN of the Lambda Cleanup execution role. Consumed by infra/modules/scheduler/."
  value       = aws_iam_role.lambda_cleanup.arn
}

output "lambda_cleanup_role_name" {
  description = "Name of the Lambda Cleanup execution role."
  value       = aws_iam_role.lambda_cleanup.name
}

# ─── SCHEDULER ROLE (EventBridge) ─────────────────────────────────────────────
output "scheduler_exec_role_arn" {
  description = "ARN of the EventBridge Scheduler execution role. Consumed by infra/modules/scheduler/."
  value       = aws_iam_role.scheduler_exec.arn
}

output "scheduler_exec_role_id" {
  description = "ID (name) of the EventBridge Scheduler role. Used by the scheduler module to attach the invoke policy."
  value       = aws_iam_role.scheduler_exec.id
}

output "scheduler_exec_role_name" {
  description = "Name of the EventBridge Scheduler role."
  value       = aws_iam_role.scheduler_exec.name
}

# ─── CI RUNNER ROLE (GitHub Actions OIDC) ─────────────────────────────────────
output "ci_runner_role_arn" {
  description = "ARN of the CI runner role assumable by GitHub Actions via OIDC. Use as role-to-assume in aws-actions/configure-aws-credentials."
  value       = aws_iam_role.ci_runner.arn
}

# ─── OIDC PROVIDER ────────────────────────────────────────────────────────────
output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider created in this module."
  value       = local.oidc_provider_arn
}