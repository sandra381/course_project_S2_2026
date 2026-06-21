# ─── DATA SOURCES ─────────────────────────────────────────────────────────────
# Se usan para construir ARNs específicos sin hardcodear account ID ni región.
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── LOCALS ───────────────────────────────────────────────────────────────────
locals {
  prefix     = "${var.project_name}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ═══════════════════════════════════════════════════════════════════════════════
# OIDC PROVIDER — GitHub Actions
# Permite que GitHub Actions asuma roles de AWS sin credenciales de larga vida.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "${local.prefix}-github-oidc-provider"
    ManagedBy = "terraform"
  }
}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.existing[0].arn
}

# ═══════════════════════════════════════════════════════════════════════════════
# ROL 1 — COMPUTE ROLE (Lambda API)
# Permisos: lectura/escritura S3 files, escritura S3 reports, envío SQS,
#           describe RDS, logs propios.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "lambda_api" {
  name = "${local.prefix}-lambda-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name      = "${local.prefix}-lambda-api-role"
    ManagedBy = "terraform"
  }
}

# S3 — files bucket (lectura y escritura) + reports bucket (solo escritura)
resource "aws_iam_role_policy" "lambda_api_s3" {
  name = "${local.prefix}-lambda-api-s3"
  role = aws_iam_role.lambda_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FilesRead"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${var.s3_files_bucket_arn}/*"
      },
      {
        Sid      = "ReportsWrite"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.s3_reports_bucket_arn}/*"
      },
      {
        Sid      = "ReportsReadWrite" # ← renombrado para reflejar ambos permisos
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"] # ← agregado GetObject
        Resource = "${var.s3_reports_bucket_arn}/*"
      }
    ]
  })
}

# SQS — solo envío (Lambda API encola los trabajos)
resource "aws_iam_role_policy" "lambda_api_sqs" {
  name = "${local.prefix}-lambda-api-sqs"
  role = aws_iam_role.lambda_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "QueueEnqueue"
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = var.sqs_queue_arn
    }]
  })
}

# RDS — solo describe (acceso de red via password, no IAM auth)
resource "aws_iam_role_policy" "lambda_api_rds" {
  name = "${local.prefix}-lambda-api-rds"
  role = aws_iam_role.lambda_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DBDescribe"
      Effect   = "Allow"
      Action   = ["rds:DescribeDBInstances"]
      Resource = var.db_instance_arn
    }]
  })
}

# CloudWatch Logs — scoped al log group propio de esta función
resource "aws_iam_role_policy" "lambda_api_logs" {
  name = "${local.prefix}-lambda-api-logs"
  role = aws_iam_role.lambda_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "OwnLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = [
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-api",
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-api:*"
      ]
    }]
  })
}

# VPC — managed policy de AWS requerida para que Lambda opere dentro de una VPC
resource "aws_iam_role_policy_attachment" "lambda_api_vpc" {
  role       = aws_iam_role.lambda_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ROL 2 — ASYNC CONSUMER ROLE (Lambda Worker)
# Permisos: consumir SQS (receive/delete/get), leer S3 files, escribir S3 reports.
# NO tiene SendMessage — Lambda Worker no encola, solo consume.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "lambda_worker" {
  name = "${local.prefix}-lambda-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name      = "${local.prefix}-lambda-worker-role"
    ManagedBy = "terraform"
  }
}

# SQS — solo consumo (los 3 permisos mínimos para event source mapping)
resource "aws_iam_role_policy" "lambda_worker_sqs" {
  name = "${local.prefix}-lambda-worker-sqs"
  role = aws_iam_role.lambda_worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "QueueConsume"
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = var.sqs_queue_arn
    }]
  })
}

# S3 — leer el CSV del files bucket, escribir el PDF en reports bucket
resource "aws_iam_role_policy" "lambda_worker_s3" {
  name = "${local.prefix}-lambda-worker-s3"
  role = aws_iam_role.lambda_worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadCSV"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.s3_files_bucket_arn}/*"
      },
      {
        Sid      = "WriteReadPDF"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${var.s3_reports_bucket_arn}/*"
      }
    ]
  })
}

# CloudWatch Logs — scoped al log group del worker
resource "aws_iam_role_policy" "lambda_worker_logs" {
  name = "${local.prefix}-lambda-worker-logs"
  role = aws_iam_role.lambda_worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "OwnLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = [
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-worker",
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-worker:*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_worker_vpc" {
  role       = aws_iam_role.lambda_worker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ROL 3a — CLEANUP EXECUTION ROLE (Lambda Cleanup)
# Permisos: acceso VPC y logs propios.
# Nota: Lambda Cleanup accede a RDS via red (password), no via IAM.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "lambda_cleanup" {
  name = "${local.prefix}-lambda-cleanup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name      = "${local.prefix}-lambda-cleanup-role"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "lambda_cleanup_logs" {
  name = "${local.prefix}-lambda-cleanup-logs"
  role = aws_iam_role.lambda_cleanup.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "OwnLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = [
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-cleanup",
        "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-cleanup:*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_cleanup_vpc" {
  role       = aws_iam_role.lambda_cleanup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ROL 3b — SCHEDULER ROLE (EventBridge Scheduler)
# Solo el trust policy aquí. La política de invoke se adjunta en el módulo
# scheduler para evitar dependencia circular con el ARN de Lambda Cleanup.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "scheduler_exec" {
  name = "${local.prefix}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "scheduler.amazonaws.com" }
    }]
  })

  tags = {
    Name      = "${local.prefix}-scheduler-role"
    ManagedBy = "terraform"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# ROL 4 — CI RUNNER ROLE (GitHub Actions OIDC)
# Asumible solo desde el repo específico en la rama main.
# Agrupa todos los permisos que Terraform necesita para plan/apply.
# ═══════════════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "ci_runner" {
  name = "${local.prefix}-ci-runner-role"

  lifecycle {
    prevent_destroy = true
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${local.prefix}-ci-runner-role"
    ManagedBy = "terraform"
  }
}

# ── CI: Terraform state backend (S3 + DynamoDB) ───────────────────────────────
resource "aws_iam_role_policy" "ci_runner_state" {
  name = "${local.prefix}-ci-state"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::${var.tf_state_bucket_name}",
          "arn:aws:s3:::${var.tf_state_bucket_name}/*"
        ]
      },
      {
        Sid    = "StateDynamo"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.tf_lock_table_name}"
      }
    ]
  })
}

# ── CI: IAM (crear/modificar roles y políticas del proyecto) ──────────────────
resource "aws_iam_role_policy" "ci_runner_iam" {
  name = "${local.prefix}-ci-iam"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageProjectRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateRole",
          "iam:PassRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:ListInstanceProfilesForRole"
        ]
        # Scoped al prefijo del proyecto para evitar acceso a otros roles
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${var.project_name}-*",
          "arn:aws:iam::${local.account_id}:policy/${var.project_name}-*",
          "arn:aws:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com",
          # Managed policies de AWS que el módulo adjunta a los roles Lambda
          "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
        ]
      }
    ]
  })
}

# ── CI: EC2 / VPC (red, subnets, security groups, NAT, IGW) ──────────────────
resource "aws_iam_role_policy" "ci_runner_ec2" {
  name = "${local.prefix}-ci-ec2"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Describe operations — AWS requiere Resource:"*" para estas acciones
        Sid    = "DescribeEC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNatGateways",
          "ec2:DescribeAddressesAttribute",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribePrefixLists"
        ]
        Resource = "*" # Requerido por AWS — estas acciones no soportan resource-level
      },
      {
        Sid    = "ManageVPCResources"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:CreateNetworkAcl",
          "ec2:DeleteNetworkAcl",
          "ec2:CreateNetworkAclEntry",
          "ec2:DeleteNetworkAclEntry",
          "ec2:ReplaceNetworkAclEntry",
          "ec2:ReplaceNetworkAclAssociation",
          "ec2:AssociateNetworkAcl",
        ]
        Resource = "*"
      }
    ]
  })
}

# ── CI: Lambda (funciones, layers, event source mappings) ────────────────────
resource "aws_iam_role_policy" "ci_runner_lambda" {
  name = "${local.prefix}-ci-lambda"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageLambdaFunctions"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:PublishVersion",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:PutFunctionConcurrency",
          "lambda:CreateEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
          "lambda:GetEventSourceMapping",
          "lambda:UpdateEventSourceMapping",
          "lambda:ListEventSourceMappings",
          "lambda:PublishLayerVersion",
          "lambda:DeleteLayerVersion",
          "lambda:GetLayerVersion",
          "lambda:AddLayerVersionPermission",
          "lambda:RemoveLayerVersionPermission",
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.project_name}-*",
          "arn:aws:lambda:${local.region}:${local.account_id}:layer:${var.project_name}-*",
          "arn:aws:lambda:${local.region}:${local.account_id}:layer:${var.project_name}-*:*",
          "arn:aws:lambda:${local.region}:${local.account_id}:event-source-mapping:*"
        ]
      }
    ]
  })
}

# ── CI: RDS ───────────────────────────────────────────────────────────────────
resource "aws_iam_role_policy" "ci_runner_rds" {
  name = "${local.prefix}-ci-rds"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeRDS"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageRDS"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:ModifyDBSubnetGroup",
          "rds:CreateDBParameterGroup",
          "rds:DeleteDBParameterGroup",
          "rds:ModifyDBParameterGroup",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource"
        ]
        Resource = [
          "arn:aws:rds:${local.region}:${local.account_id}:db:${var.project_name}-*",
          "arn:aws:rds:${local.region}:${local.account_id}:subgrp:${var.project_name}-*",
          "arn:aws:rds:${local.region}:${local.account_id}:pg:${var.project_name}-*"
        ]
      }
    ]
  })
}

# ── CI: S3 (buckets de la app) ────────────────────────────────────────────────
resource "aws_iam_role_policy" "ci_runner_s3_app" {
  name = "${local.prefix}-ci-s3-app"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageAppBuckets"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetBucketCORS",
          "s3:PutBucketCORS",
          "s3:DeleteBucketCORS",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      }
    ]
  })
}

# ── CI: SQS ───────────────────────────────────────────────────────────────────
resource "aws_iam_role_policy" "ci_runner_sqs" {
  name = "${local.prefix}-ci-sqs"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManageSQS"
      Effect = "Allow"
      Action = [
        "sqs:CreateQueue",
        "sqs:DeleteQueue",
        "sqs:GetQueueAttributes",
        "sqs:SetQueueAttributes",
        "sqs:ListQueues",
        "sqs:TagQueue",
        "sqs:UntagQueue",
        "sqs:GetQueueUrl"
      ]
      Resource = "arn:aws:sqs:${local.region}:${local.account_id}:*"
    }]
  })
}

# ── CI: API Gateway v2 ────────────────────────────────────────────────────────
resource "aws_iam_role_policy" "ci_runner_apigw" {
  name = "${local.prefix}-ci-apigw"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManageAPIGateway"
      Effect = "Allow"
      Action = [
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:PUT",
        "apigateway:PATCH",
        "apigateway:DELETE",
        "apigateway:TagResource",
        "apigateway:UntagResource"
      ]
      Resource = "arn:aws:apigateway:${local.region}::/*"
    }]
  })
}

# ── CI: EventBridge Scheduler ─────────────────────────────────────────────────
resource "aws_iam_role_policy" "ci_runner_scheduler" {
  name = "${local.prefix}-ci-scheduler"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManageScheduler"
      Effect = "Allow"
      Action = [
        "scheduler:CreateSchedule",
        "scheduler:DeleteSchedule",
        "scheduler:GetSchedule",
        "scheduler:UpdateSchedule",
        "scheduler:ListSchedules",
        "scheduler:TagResource",
        "scheduler:UntagResource"
      ]
      Resource = "arn:aws:scheduler:${local.region}:${local.account_id}:schedule/default/${var.project_name}-*"
    }]
  })
}

# ── CI: CloudWatch + SNS + Budgets (para módulo observability en D5) ──────────
resource "aws_iam_role_policy" "ci_runner_observability" {
  name = "${local.prefix}-ci-observability"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup",
          "logs:ListTagsLogGroup"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/${var.environment}/*"
      },
      {
        Sid    = "CloudWatchAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutDashboard",
          "cloudwatch:DeleteDashboards",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = [
          "arn:aws:cloudwatch:${local.region}:${local.account_id}:alarm:${var.project_name}-*",
          "arn:aws:cloudwatch::${local.account_id}:dashboard/${var.project_name}-*"
        ]
      },
      {
        Sid    = "SNSTopics"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListTopics",
          "sns:ListSubscriptionsByTopic",
          "sns:TagResource",
          "sns:UntagResource"
        ]
        Resource = "arn:aws:sns:${local.region}:${local.account_id}:${var.project_name}-*"
      },
      {
        Sid    = "Budgets"
        Effect = "Allow"
        Action = [
          "budgets:CreateBudget",
          "budgets:ModifyBudget",
          "budgets:DeleteBudget",
          "budgets:ViewBudget"
        ]
        Resource = "arn:aws:budgets::${local.account_id}:budget/${var.project_name}-*"
      }
    ]
  })
}

# ── CI: Secrets Manager + KMS (para módulo secrets en D5) ────────────────────
resource "aws_iam_role_policy" "ci_runner_secrets_kms" {
  name = "${local.prefix}-ci-secrets-kms"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:ListSecrets",
          "secretsmanager:RestoreSecret"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-*"
      },
      {
        Sid    = "KMSManage"
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:EnableKey",
          "kms:DisableKey",
          "kms:GetKeyPolicy",
          "kms:PutKeyPolicy",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:DescribeKey",
          "kms:ListAliases",
          "kms:ListKeys",
          "kms:TagResource",
          "kms:ListResourceTags",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:GetKeyRotationStatus",
          "kms:EnableKeyRotation"
        ]
        Resource = "*" # KMS keys no tienen ARN predecible hasta su creación
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ci_runner_readonly" {
  role       = aws_iam_role.ci_runner.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "ci_runner_dns_tls_observability" {
  name = "${local.prefix}-ci-dns-tls-observability"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ACMManage"
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate",
          "acm:DeleteCertificate",
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate"
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53Manage"
        Effect = "Allow"
        Action = [
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
          "route53:ChangeResourceRecordSets",
          "route53:ChangeTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "LogsManage"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:TagResource",
          "logs:UntagResource"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/*"
      },
      {
        Sid    = "CloudFrontManage"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:TagResource",
          "cloudfront:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "SNSManage"
        Effect = "Allow"
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:TagResource",
          "sns:UntagResource"
        ]
        Resource = "arn:aws:sns:${local.region}:${local.account_id}:${var.project_name}-*"
      },
      {
        Sid    = "CloudWatchAlarmsManage"
        Effect = "Allow"
        Action = [
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "BudgetsManage"
        Effect = "Allow"
        Action = [
          "budgets:TagResource",
          "budgets:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

/* resource "aws_iam_role_policy" "ci_runner_ses" {
  name = "${local.prefix}-ci-ses"
  role = aws_iam_role.ci_runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SESManage"
        Effect = "Allow"
        Action = [
          "ses:VerifyEmailIdentity",
          "ses:DeleteIdentity",
          "ses:GetIdentityVerificationAttributes",
          "ses:GetIdentityDkimAttributes",
          "ses:GetIdentityNotificationAttributes",
          "ses:GetIdentityMailFromDomainAttributes",
          "ses:GetIdentityPolicies",
          "ses:ListIdentities",
          "ses:ListIdentityPolicies",
          "ses:ListTagsForResource",
          "ses:TagResource",
          "ses:UntagResource",
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SetIdentityMailFromDomain",
          "ses:SetIdentityNotificationTopic",
          "ses:VerifyDomainIdentity",
          "ses:VerifyDomainDkim"
        ]
        Resource = "*"
      }
    ]
  })
}*/
resource "aws_iam_policy" "ci_runner_ses" {
  name        = "${local.prefix}-ci-ses"
  description = "SES permissions for CI runner"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SESManage"
        Effect = "Allow"
        Action = [
          "ses:VerifyEmailIdentity",
          "ses:DeleteIdentity",
          "ses:GetIdentityVerificationAttributes",
          "ses:GetIdentityDkimAttributes",
          "ses:GetIdentityNotificationAttributes",
          "ses:GetIdentityMailFromDomainAttributes",
          "ses:GetIdentityPolicies",
          "ses:ListIdentities",
          "ses:ListIdentityPolicies",
          "ses:ListTagsForResource",
          "ses:TagResource",
          "ses:UntagResource",
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SetIdentityMailFromDomain",
          "ses:SetIdentityNotificationTopic",
          "ses:VerifyDomainIdentity",
          "ses:VerifyDomainDkim"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ci_runner_ses" {
  role       = aws_iam_role.ci_runner.name
  policy_arn = aws_iam_policy.ci_runner_ses.arn
}

resource "aws_iam_role_policy" "lambda_worker_ses" {
  name = "${local.prefix}-lambda-worker-ses"
  role = aws_iam_role.lambda_worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SendReportEmail"
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
    }]
  })
}
