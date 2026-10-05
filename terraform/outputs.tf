output "s3_bucket_name" {
  description = "S3 bucket storing ISS location data"
  value       = aws_s3_bucket.iss_data.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket storing ISS location data"
  value       = aws_s3_bucket.iss_data.arn
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account IAM role in Account B"
  value       = aws_iam_role.cross_account_s3_write.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role in Account A"
  value       = aws_iam_role.lambda_execution.arn
}