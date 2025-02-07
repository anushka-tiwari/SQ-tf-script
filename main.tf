
resource "aws_db_subnet_group" "sonar_rds_subnet_group" {
  name       = "${local.project}-${var.environment_abbreviation}-sql-rds-sg"
  subnet_ids = data.aws_subnets.subnet.ids
  tags = {
    Name = "${local.resource_name_prefix}-sql-rds-sg"
  }
}

resource "aws_security_group" "rds_security_group" {
  name        = "${local.project}-${var.environment_abbreviation}-sql-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
   tags = {
    Name = "${local.resource_name_prefix}-sql-rds-security-group"
  }
}

resource "aws_security_group" "lambda_security_group" {
  name        = "${local.project}-${var.environment_abbreviation}-sql-lambda-sg"
  description = "Security group for lambda function which will be communicating with the rds"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
   tags = {
    Name = "${local.resource_name_prefix}-sql-lambda-security-group"
  }
}
#################################################################################################################################
resource "aws_db_option_group" "sonar_sqlserver_option_group" {
  name                     = "${local.project}-${var.environment_abbreviation}-sqlserverrestore"
  engine_name              = "sqlserver-se"
  major_engine_version     = "16.00"
  option_group_description = "Option group for sonarqube SQL Server backup and restore"

  option {
    option_name = "SQLSERVER_BACKUP_RESTORE"
    option_settings {
      name  = "IAM_ROLE_ARN"
      value = aws_iam_role.rds_backup_restore_role.arn
    }
  }
}

#################################################################################################################################

#creating the MSSQL RDS instance
resource "aws_db_instance" "rds_sql_db_sonarqube" {
  depends_on        = [aws_db_option_group.sonar_sqlserver_option_group]
  identifier        = "${local.project}-${local.region-alias}-${var.environment_abbreviation}-mssql-rdsdb"
  allocated_storage = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type      = var.storage_type
  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  username             = jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["username"]
  password             = jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["password"]
  publicly_accessible = var.publicly_accessible
  multi_az            = var.multi_az
  skip_final_snapshot = var.skip_final_snapshot
  license_model       = "license-included"
  backup_retention_period = 2
  backup_window           = "03:00-04:00"
  storage_encrypted    = true
  kms_key_id           = aws_kms_key.sonarqube_rds_kms.arn
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  option_group_name = aws_db_option_group.sonar_sqlserver_option_group.name

  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.sonar_rds_subnet_group.name

  timeouts {
    create = "60m"
  }

    tags = {
    "Name" = local.resource_name_prefix
  }
}


############################################################################################################################

# Creating Lambda function package for db_initializer lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/createDB_lambda_script"
  output_path = "${path.module}/lambda_function_payload.zip"
}

# Creating Lambda function package for db_initializer_verify lambda function
data "archive_file" "lambda_zip1" {
  type        = "zip"
  source_dir  = "${path.module}/VerifyDB_lambda_script"
  output_path = "${path.module}/lambda_function_payload1.zip"
}

# Creating Lambda function package for db_initializer_dump for lambda function
data "archive_file" "lambda_zip2" {
  type        = "zip"
  source_dir  = "${path.module}/RestoreDB_lambda_script"
  output_path = "${path.module}/lambda_function_payload2.zip"
}


#Creating Lambdalayer package
data "archive_file" "pymssql_dependencies" {
  type        = "zip"
  source_dir  = "${path.module}/lambdalayer/pymssql_layer"
  output_path = "${path.module}/lambdalayer/pymssql_layer_payload.zip"
}

#Create Lambda layer with dependencies
resource "aws_lambda_layer_version" "dependencies" {
  #filename     = "${path.module}/lambda/dependencies.zip"
  filename      = data.archive_file.pymssql_dependencies.output_path
  layer_name    = "mssql-rds-dependencies"
  description   = "Lambda layer for MSSQL RDS dependencies"
  compatible_runtimes = ["python3.11"]
}


# Creating Lambda function to create the database and user on RDS instance
resource "aws_lambda_function" "db_initializer" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.project}-${var.environment_abbreviation}-lambda-create-db"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 100
  layers           = [aws_lambda_layer_version.dependencies.arn]
  vpc_config {
    security_group_ids = [aws_security_group.lambda_security_group.id]
    #subnet_ids        = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    subnet_ids         = data.aws_subnets.subnet.ids
  }

   depends_on = [
    data.archive_file.lambda_zip
  ]

  environment {
    variables = {
      RDS_SECRETS = aws_secretsmanager_secret.secrets.name
      DB_ENDPOINT = aws_db_instance.rds_sql_db_sonarqube.endpoint
      DB_SECRETS  = aws_secretsmanager_secret.sonar_db_user_secrets.name
    }
  }
}


##########################################################################################################################

# Creating Lambda function to Verify database the database creation
resource "aws_lambda_function" "db_initializer_verify" {
  filename         = data.archive_file.lambda_zip1.output_path
  function_name    = "${local.project}-${var.environment_abbreviation}-lambda-Dbverify"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 100
  layers           = [aws_lambda_layer_version.dependencies.arn]
  vpc_config {
    security_group_ids = [aws_security_group.lambda_security_group.id]
    #subnet_ids        = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    subnet_ids         = data.aws_subnets.subnet.ids
  }

   depends_on = [
    data.archive_file.lambda_zip1
  ]

  environment {
    variables = {
      DB_ENDPOINT = aws_db_instance.rds_sql_db_sonarqube.endpoint
      RDS_SECRETS = aws_secretsmanager_secret.secrets.name
    }
  }
}


########################################################################################################################

# Creating Lambda function to restore the database backup from s3 to rds
resource "aws_lambda_function" "db_initializer_dump" {
  filename         = data.archive_file.lambda_zip2.output_path
  function_name    = "${local.project}-${var.environment_abbreviation}-lambda-Db-restore"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 100
  layers           = [aws_lambda_layer_version.dependencies.arn]
  vpc_config {
    security_group_ids = [aws_security_group.lambda_security_group.id]
    #subnet_ids        = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    subnet_ids         = data.aws_subnets.subnet.ids
  }

   depends_on = [
    data.archive_file.lambda_zip2
  ]

  environment {
    variables = {
      RDS_SECRETS = aws_secretsmanager_secret.secrets.name
      DB_ENDPOINT = aws_db_instance.rds_sql_db_sonarqube.endpoint
      DB_NAME = var.restore_db_name
      S3_KEYS   = var.backup_file_name
      S3_BUCKET = var.s3_bucket_name
      IAM_ROLE_ARN = aws_iam_role.rds_backup_restore_role.arn
    }
  }
}

########################################################################################################################


output "rds_endpoint" {
  value = aws_db_instance.rds_sql_db_sonarqube.endpoint
}
