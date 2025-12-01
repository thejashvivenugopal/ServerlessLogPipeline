variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "aws-region"
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
  default     = "aws-profile"
}

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "memorymachines"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "env"
}

variable "ingest_lambda_zip" {
  description = "Path to built zip for ingest Lambda"
  type        = string
}

variable "worker_lambda_zip" {
  description = "Path to built zip for worker Lambda"
  type        = string
}
