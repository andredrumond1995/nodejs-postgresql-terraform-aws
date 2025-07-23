variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "sa-east-1"
}

variable "db_name" {
  description = "Database name for Postgres"
  type        = string
  default     = "todos_db"
}

variable "db_user" {
  description = "Database user for Postgres"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password for Postgres"
  type        = string
  sensitive   = true
}

variable "api_image" {
  description = "Docker image for the API"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "api-pg-todo"
} 