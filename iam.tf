# Creating IAM role for Lambda function
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${local.project}-${var.environment_abbreviation}-mssql-rds-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda_secrets_policy" {
  name        = "${local.project}-${var.environment_abbreviation}-lambda-secrets-policy"
  description = "Policy for granting Lambda access to secrets in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_secrets_policy_attachment" {
  name       = "${local.project}-${var.environment_abbreviation}-lambda-secrets-policy-attachment"
  roles      = [aws_iam_role.lambda_role.id]
  policy_arn = aws_iam_policy.lambda_secrets_policy.arn
}



resource "aws_iam_role_policy" "rds_restore_policy_attachment" {
  name   = "${local.project}-${var.environment_abbreviation}-mssql-rds-restore-policy"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "rds:RestoreDBInstanceFromS3"
        Resource = aws_db_option_group.sonar_sqlserver_option_group.arn
      }
    ]
  })
}

#########################################################
resource "aws_iam_policy" "lambda_pass_role_policy" {
  name        = "${local.project}-${var.environment_abbreviation}-rds-lambda-pass-rolepolicy"
  description = "IAM policy to allow Lambda to pass roles to RDS"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "iam:PassRole",
        Resource = aws_iam_role.rds_backup_restore_role.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_pass_role_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_pass_role_policy.arn
}



###########################################################
# Attaching basic Lambda execution policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy to allow Lambda function to log to CloudWatch
resource "aws_iam_policy_attachment" "lambda_cloudwatch_logs" {
  name       = "lambda_cloudwatch_logs"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

# Policy to allow Lambda function to access VPC resources
resource "aws_iam_policy_attachment" "lambda_vpc_access" {
  name       = "lambda_vpc_access"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}



resource "aws_iam_policy_attachment" "lambda_layer_policy" {
  name       = "lambda_layer_policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.lambda_layer_policy.arn
}

resource "aws_iam_policy" "lambda_layer_policy" {
  name        = "${local.project}-${var.environment_abbreviation}-lambda-layer-policy"
  description = "Policy for accessing the lambda layer"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "lambda:GetLayerVersion"
        Resource  = aws_lambda_layer_version.dependencies.arn
      }
    ]
  })
}


resource "aws_iam_policy" "lambda_rds_full_access_policy" {
  name        = "${local.project}-${var.environment_abbreviation}-lambda-rds-full-access-policy"
  description = "IAM policy for Lambda function with full access to sonar RDS instances"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "rds:*",
        Resource = [
          aws_db_instance.rds_sql_db_sonarqube.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_rds_full_access_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_rds_full_access_policy.arn
}




# IAM Policy for RDS Access and Modification
resource "aws_iam_policy" "lambda_rds_policy" {
  name = "${local.project}-${var.environment_abbreviation}-lambda-rds-policy"
  description = "IAM policy for Lambda function to access and modify RDS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds-db:connect",
          "rds-db:createUser",
          "rds-db:modifyDBInstance",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ListTagsForResource",
          "rds:RestoreDBInstanceFromS3",
          "rds:DescribeEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "lambda_rds_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_rds_policy.arn
}


resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "${local.project}-${var.environment_abbreviation}-rds-lambda-s3-policy"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}


#############IAM FOR RDS#########################################################################################

resource "aws_iam_role" "sonarqube_rds_monitoring_role" {
  name               = "${local.project}-${var.environment_abbreviation}-SonarRDSMonitoringRole2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "attach_rds_monitoring_policy" {
  name       = "${local.project}-${var.environment_abbreviation}-RSD-cloudwatchlogs"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  roles      = [aws_iam_role.sonarqube_rds_monitoring_role.name]
}



###############################################################################################################

resource "aws_iam_role" "rds_backup_restore_role" {
  name = "${local.project}-${var.environment_abbreviation}-sql-server-backup-restore"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "rds_backup_restore_s3_policy" {
  name = "${local.project}-${var.environment_abbreviation}-RDSBackupRestoreS3Policy"
  role = aws_iam_role.rds_backup_restore_role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::${var.s3_bucket_name}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObjectMetaData",
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload"
            ],
            "Resource": [
                "arn:aws:s3:::${var.s3_bucket_name}/*"
            ]
        }
    ]
  })
}

