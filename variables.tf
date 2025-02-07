variable "environment" {
  type        = string
  description = "The name of the environment to deploy (full name)"
}

variable "environment_abbreviation" {
  type        = string
  description = "The name of the environment to deploy"
}

variable "track" {
  type        = string
  description = "Track number"
}

variable "s3_bucket_name" {
  type        = string
  description = "The name of the s3 bucket that contain the database backup from on-prem"
}

variable "backup_file_name" {
  type        = string
  description = "The name of the backup file in s3 bucket"
}

variable "restore_db_name" {
  type        = string
  description = "The name of that we want to give for the database that is being restored into mssql rds"
}

variable "allocated_storage" {
  description = "The allocated storage size for the RDS instance (in GB)"
  default     = 30
}

variable "max_allocated_storage" {
  description = "The maximum allocated storage size for the RDS instance (in GB)"
  default     = 200
}

variable "storage_type" {
  description = "The type of storage for the RDS instance"
  default     = "gp2"
}

variable "engine" {
  description = "The database engine for the RDS instance"
  default     = "sqlserver-se"
}

variable "engine_version" {
  description = "The version of the database engine for the RDS instance"
  default     = "16.00.4125.3.v1"
}

variable "instance_class" {
  description = "The instance class for the RDS instance"
  default     = "db.m5.large"
}

variable "publicly_accessible" {
  description = "Whether the RDS instance should be publicly accessible"
  default     = false
}

variable "multi_az" {
  description = "Whether to create the RDS instance as a Multi-AZ deployment"
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip taking a final snapshot upon deletion of the RDS instance"
  default     = true
}

