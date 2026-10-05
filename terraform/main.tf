resource "aws_s3_bucket" "iss_data" {
  provider = aws.account_b

  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "iss_data" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.iss_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "cross_account_s3_write" {
  provider = aws.account_b

  name = var.cross_account_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          AWS = aws_iam_role.lambda_execution.arn
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cross_account_s3_write" {
  provider = aws.account_b

  name = "AllowISSDataUpload"
  role = aws_iam_role.cross_account_s3_write.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.iss_data.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_execution" {
  provider = aws.account_a

  name = var.lambda_execution_role_name
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  provider = aws.account_a

  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_assume_cross_account" {
  provider = aws.account_a

  name = "AllowCrossAccountAssumeRole"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "sts:AssumeRole"
        ]

        Resource = aws_iam_role.cross_account_s3_write.arn
      }
    ]
  })
}

