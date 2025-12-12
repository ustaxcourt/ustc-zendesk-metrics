data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.assume_role_services
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.project_name}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# AWS OIDC <--> Github actions IAM Role
resource "aws_iam_role" "github_actions_deployer" {
  name = local.deploy_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GithubOIDCAssumeRole"
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.github_sub
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_permissions" {
  name = "zendesk-metrics-ci-deployer"
  role = aws_iam_role.github_actions_deployer.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:ListBucket"],
        Resource = "arn:aws:s3:::${local.tf_state_bucket_name}"
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject","s3:PutObject","s3:DeleteObject"],
        Resource = [
          "arn:aws:s3:::${local.tf_state_bucket_name}/*"
        ]
      },
      # Read access to build artifacts used for Lambda code updates
      {
        Effect  = "Allow",
        Action  = ["s3:GetObject", "s3:HeadObject"],
        Resource = "arn:aws:s3:::${var.artifacts_bucket_name}/artifacts/*"
      },
      {
        Effect  = "Allow",
        Action  = ["s3:ListBucket"],
        Resource = "arn:aws:s3:::${var.artifacts_bucket_name}"
      },
      { #lock table
        Effect   = "Allow",
        Action   = ["dynamodb:DescribeTable","dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:DeleteItem"],
        Resource = "arn:aws:dynamodb:${local.aws_region}:${data.aws_caller_identity.current.account_id}:table/${local.tf_lock_table_name}"
      },
      {
        Effect = "Allow",
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:DeleteFunction",
          "lambda:GetFunction*",
          "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:TagResource",
          "lambda:UntagResource"
        ],
        Resource = "arn:aws:lambda:${local.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.project_name}*"
      },
      {
        Effect   = "Allow",
        Action   = ["iam:PassRole"],
        Resource = local.lambda_exec_role_arn,
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow",
        Action = ["iam:GetRole","iam:ListRolePolicies","iam:GetRolePolicy","iam:ListAttachedRolePolicies"],
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.deploy_role_name}",
          local.lambda_exec_role_arn
        ]
      },
      {
        Effect = "Allow",
        Action = ["apigateway:GET",
                  "apigateway:POST",
                  "apigateway:PUT",
                  "apigateway:PATCH",
                  "apigateway:DELETE"],
        Resource = [
          "arn:aws:apigateway:${local.aws_region}::/restapis*",
          "arn:aws:apigateway:${local.aws_region}::/deployments*",
          "arn:aws:apigateway:${local.aws_region}::/domainnames*",
          "arn:aws:apigateway:${local.aws_region}::/basepathmappings*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["acm:ListCertificates","acm:DescribeCertificate"],
        Resource = "*"
      },
      {
        Effect = "Allow", #cloudwatch logs
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:PutRetentionPolicy"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow", # delete/manage PR Lambda log groups
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:PutSubscriptionFilter",
          "logs:DeleteSubscriptionFilter",
          "logs:DeleteLogGroup"
        ],
        Resource = "arn:aws:logs:${local.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.project_name}-*"
      },
      {
        Effect = "Allow", #secrets manager
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:PutResourcePolicy",
          "secretsmanager:DeleteResourcePolicy",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource"
        ],
        Resource = [
          "arn:aws:secretsmanager:${local.aws_region}:${data.aws_caller_identity.current.account_id}:secret:ZendeskDawson-*",
        ]
      },
      {
        Effect = "Allow", #iam role creation (for self-management)
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListInstanceProfilesForRole",
          "iam:TagRole",
          "iam:UntagRole"
        ],
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project_name}-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*lambda*"
        ]
      },
      {
        Effect = "Allow", #iam policy management
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy"
        ],
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/build-artifacts-access-policy",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.project_name}-*"
        ]
      },
      {
        Effect = "Allow", # CloudWatch EventBridge Rule
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:DescribeRule",
          "events:EnableRule",
          "events:DisableRule",
          "events:ListTagsForResource",
          "events:DeleteRule",
          "events:ListTargetsByRule",
          "events:RemoveTargets"
        ],
        Resource = "arn:aws:events:${local.aws_region}:${data.aws_caller_identity.current.account_id}:rule/updateMetricsDatabaseCronRule"
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ListQueues",
          "sqs:ListQueueTags",
          "sqs:TagQueue",
        ],
        Resource = [
          var.job_queue_arn,
          var.dlq_queue_arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:GetBucketTagging",
          "s3:GetLifecycleConfiguration",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucketVersions",
          "s3:PutBucketTagging",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketWebsite",
          "s3:GetBucketVersioning",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketLogging",
          "s3:GetReplicationConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketObjectLockConfiguration",
        ],
        Resource = [
          "arn:aws:s3:::${local.project_name}-${var.environment}-athena-database",
          "arn:aws:s3:::${local.project_name}-${var.environment}-athena-results",
          "arn:aws:s3:::${local.project_name}-${var.environment}-ticket-data",
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = "arn:aws:s3:::${local.project_name}-${var.environment}-athena-database/*"
      },
      {
          Effect = "Allow",
          Action = [
            "glue:CreateDatabase",
            "glue:CreateTable",
            "glue:UpdateTable",
            "glue:DeleteTable",
            "glue:GetDatabase",
          ],
          Resource = [
            "arn:aws:glue:${local.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
            "arn:aws:glue:${local.aws_region}:${data.aws_caller_identity.current.account_id}:database/metrics_database",
            "arn:aws:glue:${local.aws_region}:${data.aws_caller_identity.current.account_id}:table/metrics_database/*"
          ]
      },
      {
        Effect = "Allow",
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetDatabase"
        ],
        Resource = [
          "arn:aws:athena:${local.aws_region}:${data.aws_caller_identity.current.account_id}:*",
        ]
      }, 
      {
        Effect = "Allow",
        Action = [
          "lambda:CreateEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
          "lambda:ListEventSourceMappings",
          "lambda:UpdateEventSourceMapping",
          "lambda:ListTags"
        ],
        Resource = [
          "arn:aws:lambda:${local.aws_region}:${data.aws_caller_identity.current.account_id}:event-source-mapping:*",
        ]
      },
      {
        Effect = "Allow",
        Action = "lambda:GetEventSourceMapping",
        Resource = "*"
      }
    ]
  })
}


data "aws_iam_policy_document" "lambda_secrets_read" {
  statement {
    sid       = "GetSecretValue"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${local.aws_region}:${data.aws_caller_identity.current.account_id}:secret:ZendeskDawson-*"]
  }
}

resource "aws_iam_role_policy" "lambda_secrets_read" {
  name   = "${local.project_name}-lambda-secrets-read"
  role   = aws_iam_role.lambda_exec.name
  policy = data.aws_iam_policy_document.lambda_secrets_read.json
}

data "aws_iam_policy_document" "lambda_sqs_read_and_write" {
  statement {
    sid       = "SQSReadWrite"
    effect    = "Allow"
    actions   = [
      "sqs:DeleteMessage", 
      "sqs:GetQueueAttributes", 
      "sqs:ReceiveMessage", 
      "sqs:SendMessage"
    ]
    resources = [
      var.job_queue_arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_sqs_read_and_write" {
  name   = "${local.project_name}-lambda-sqs-read-and-write"
  role   = aws_iam_role.lambda_exec.name
  policy = data.aws_iam_policy_document.lambda_sqs_read_and_write.json
}

data "aws_iam_policy_document" "lambda_s3_read_and_write" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment}-athena-database",
      "arn:aws:s3:::${var.project_name}-${var.environment}-athena-results",
      "arn:aws:s3:::${var.project_name}-${var.environment}-ticket-data",
      "arn:aws:s3:::${var.project_name}-${var.environment}-athena-database/*",
      "arn:aws:s3:::${var.project_name}-${var.environment}-athena-results/*",
      "arn:aws:s3:::${var.project_name}-${var.environment}-ticket-data/*"
    ]
  }
}
resource "aws_iam_role_policy" "lambda_s3_read_and_write" {
  name   = "${local.project_name}-lambda-s3-read-and-write"
  role   = aws_iam_role.lambda_exec.name
  policy = data.aws_iam_policy_document.lambda_s3_read_and_write.json
}
