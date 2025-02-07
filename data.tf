data "aws_vpc" "vpc" {
  tags = {
    Name = "prov-mainvpc-primary-vpc"
  }
}

data "aws_subnets" "subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["subnet-Data-*"]
  }
}


data "aws_secretsmanager_secret_version" "secrets" {
    depends_on = [aws_secretsmanager_secret_version.secrets]
    secret_id = aws_secretsmanager_secret.secrets.id
}

data "aws_secretsmanager_secret_version" "sonar_db_user_secrets" {
    depends_on = [aws_secretsmanager_secret_version.sonar_db_user_secrets]
    secret_id = aws_secretsmanager_secret.sonar_db_user_secrets.id
}

