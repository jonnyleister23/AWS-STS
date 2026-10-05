variable "aws_region" {
  description = "AWS region used for the project"
  type        = string
  default     = "us-east-2"
}

variable "account_a_profile" {
  description = "AWS CLI profile for Account A"
  type        = string
  default     = "account-a"
}

variable "account_b_profile" {
  description = "AWS CLI profile for Account B"
  type        = string
  default     = "account-b"
}

variable "bucket_name" {
  description = "Name of the S3 bucket used to store ISS location data"
  type        = string
}

variable "cross_account_role_name" {
  description = "IAM role in Account B that allows cross-account S3 writes"
  type        = string
  default     = "CrossAccountS3WriteRole"
}

variable "lambda_execution_role_name" {
  description = "IAM execution role used by the Lambda function in Account A"
  type        = string
}