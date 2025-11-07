# infrastructure/variables.tf

variable "project_name" {
  description = "project name"
  type        = string
  default     = "NTI-FINAL"
}

variable "aws_region" {
  description = "avz"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR  VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "available_zones" {
  description = "A list of Availability Zones (AZs) to use for high availability infrastructure deployment."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "app_port" {
  description = "ECS."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "(PostgreSQL/MySQL)."
  type        = number
  default     = 5432
}