data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "sonarqube_rds_kms" {
  description             = "KMS Key for Sonarqube MSSQL RDS and Secrets Manager"
  deletion_window_in_days = 10

  policy = jsonencode({
    Id = "AllowRDSAndSecretsManagerAccess"
    Statement = [
      {
        Sid = "Allow access to KMS from various accounts"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
            "arn:aws:iam::########:root",
            "arn:aws:iam::########:root"
          ]
        }
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ListGrants",
          "kms:ReEncrypt*",
          "kms:RevokeGrant"
        ]
        Resource = "*"
      },
      {
        Sid = "Allow access through Secrets Manager and RDS"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount": "${data.aws_caller_identity.current.account_id}",
            "kms:ViaService": [
              "secretsmanager.${data.aws_region.current.name}.amazonaws.com",
              "rds.${data.aws_region.current.name}.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid = "Allow administration of the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_kms_alias" "sonarqube_rds_kms" {
  name          = "alias/${local.project}-${local.region-alias}-${var.environment_abbreviation}-${var.track}-rds-kms-key"
  target_key_id = aws_kms_key.sonarqube_rds_kms.key_id
}



resource "aws_iam_role" "sonarqube_rds_kms_role" {
  name = "sonarqube-rds-kms-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "secretsmanager.amazonaws.com",
            "rds.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_policy" "sonarqube_rds_kms_policy" {
  name        = "sonarqube-rds-kms-policy"
  description = "Policy to allow RDS and Secretsmanager to use the KMS key for encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.sonarqube_rds_kms.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sonarqube_rds_kms_policy_attachment" {
  role       = aws_iam_role.sonarqube_rds_kms_role.name
 policy_arn = aws_iam_policy.sonarqube_rds_kms_policy.arn
 }
