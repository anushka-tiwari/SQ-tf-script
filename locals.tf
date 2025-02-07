data "aws_regions" "current" {}

locals {
  project            = "sonarqube"
  region-alias       = "euc1"

  resource_name_prefix = format("%s-%s-%s-%s", local.project, local.region-alias, var.environment_abbreviation, "rds-mssqldb")

}

