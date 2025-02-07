resource "random_password" "password"{
    length           = 16
    special          = true
    override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "secrets"{
    kms_key_id   = aws_kms_key.sonarqube_rds_kms.key_id
    name         = "${local.project}-${var.environment_abbreviation}-RDS-credential"
    description  = "Sonarqube RDS db Admin username and password"
    recovery_window_in_days = 14
    tags ={
        Name = "${local.resource_name_prefix}-RDS-credential"
    }
}
resource "aws_secretsmanager_secret_version" "secrets"{
    secret_id = aws_secretsmanager_secret.secrets.id
    secret_string = jsonencode({
        username = "admin",
        password = random_password.password.result
    })
}

######################################################################################################################

resource "random_password" "sonar_db_user_password"{
    length           = 16
    special          = true
    override_special = "_!%^"
}


resource "aws_secretsmanager_secret" "sonar_db_user_secrets"{
    kms_key_id   = aws_kms_key.sonarqube_rds_kms.key_id
    name         = "${local.project}-${var.environment_abbreviation}-database-credential"
    description  = "Sonarqube user database credentials"
    recovery_window_in_days = 14
    tags ={
        Name = "${local.resource_name_prefix}-database-credential"
    }
}
resource "aws_secretsmanager_secret_version" "sonar_db_user_secrets"{
    secret_id = aws_secretsmanager_secret.sonar_db_user_secrets.id
    secret_string = jsonencode({
        database = "sonarqubesqldb",
        username = "sonarqubeuser",
        password = random_password.sonar_db_user_password.result
    })
}
