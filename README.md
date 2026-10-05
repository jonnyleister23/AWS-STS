# AWS-STS

This project demonstrates how AWS Security Token Service (STS) can be used to securely access resources across two separate AWS accounts.

I built a Lambda function in Account A that retrieves the current location of the International Space Station (ISS) from a public API. Instead of giving the Lambda direct credentials to Account B, the function uses AWS STS to assume an IAM role in Account B. STS provides temporary credentials that the Lambda uses to upload the ISS location data as a JSON file to an S3 bucket.

I also used Terraform to manage the IAM roles, policies, trust relationships, S3 bucket, and bucket versioning used by the project.

## Architecture

```text
                    ACCOUNT A
              ┌──────────────────┐
              │  Lambda Function │
              │                  │
              │ Gets current ISS │
              │ location from API│
              └────────┬─────────┘
                       │
                       │ Uses execution role
                       ▼
              ┌──────────────────┐
              │ Lambda Execution │
              │      Role        │
              └────────┬─────────┘
                       │
                       │ sts:AssumeRole
                       ▼
                    AWS STS
                       │
                       │ Temporary credentials
                       ▼
                    ACCOUNT B
              ┌──────────────────┐
              │ CrossAccountS3   │
              │    WriteRole     │
              └────────┬─────────┘
                       │
                       │ s3:PutObject
                       ▼
              ┌──────────────────┐
              │    S3 Bucket     │
              │                  │
              │ ISS location     │
              │ JSON objects     │
              └──────────────────┘
```

## How It Works

The Lambda function first makes a request to the Open Notify API to retrieve the current latitude and longitude of the ISS.

The Lambda runs using an execution role in Account A. This role has permission to call `sts:AssumeRole` on the `CrossAccountS3WriteRole` located in Account B.

Account B has a trust policy on `CrossAccountS3WriteRole` that allows the Lambda execution role from Account A to assume it.

When the Lambda calls STS, it receives temporary AWS credentials for the Account B role. These credentials are then used to create an S3 client and upload the ISS data to the bucket in Account B.

Each execution creates a timestamped object such as:

```text
iss-location-2026-10-05-00-12-54.json
```

This approach avoids storing long-term Account B credentials inside the Lambda function.

## IAM Permissions

There are two main IAM roles involved in the project.

### Lambda Execution Role - Account A

The Lambda execution role allows the function to run in Account A. It has:

- `AWSLambdaBasicExecutionRole` for standard Lambda logging
- Permission to call `sts:AssumeRole` on the cross-account role in Account B

The role's trust policy allows the AWS Lambda service to assume it.

### Cross-Account S3 Role - Account B

`CrossAccountS3WriteRole` exists in Account B.

Its trust policy allows the Lambda execution role from Account A to assume it. Once assumed, the role gives the temporary session permission to use `s3:PutObject` on the project's S3 bucket.

The S3 permissions are intentionally limited to the actions required by the Lambda rather than giving the function broad access to Account B.

## Terraform

Terraform is used to manage the infrastructure and IAM configuration for the project.

The Terraform configuration manages:

- S3 bucket
- S3 bucket versioning
- Lambda execution IAM role
- Lambda basic execution policy attachment
- Cross-account `sts:AssumeRole` permission
- Account B cross-account IAM role
- Account B trust relationship
- S3 upload permissions

The Lambda function itself was created separately in AWS, while Terraform manages the supporting IAM and S3 infrastructure.

I used two AWS provider configurations so Terraform can work with both AWS accounts:

```text
aws.account_a
aws.account_b
```

Authentication to the accounts is handled through AWS IAM Identity Center/SSO rather than permanent access keys.

## Project Structure

```text
AWS-STS/
├── README.md
├── .gitignore
│
├── lambda/
│   └── lambda_function.py
│
└── terraform/
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    └── outputs.tf
```

## Lambda

The Lambda function is written in Python using `boto3`.

The Account B role ARN and S3 bucket name are provided through Lambda environment variables:

```text
ROLE_ARN
BUCKET_NAME
```

The basic flow of the function is:

1. Request the current ISS location.
2. Call AWS STS to assume the Account B role.
3. Receive temporary credentials from STS.
4. Create an S3 client using those credentials.
5. Upload the ISS response as a timestamped JSON object.

No AWS access keys are stored in the source code.

## Testing

I tested the project by invoking the Lambda function from Account A.

A successful execution returns a response similar to:

```json
{
  "statusCode": 200,
  "body": "{\"message\": \"ISS location successfully uploaded to Account B\", \"file\": \"iss-location-2026-10-05-00-12-54.json\"}"
}
```

I then verified that the corresponding JSON object was created in the S3 bucket in Account B.

The Terraform configuration can also be checked with:

```bash
terraform fmt -check
terraform validate
terraform plan
```

A clean configuration should produce a successful validation and no unexpected infrastructure changes.

## Issues I Ran Into

One of the more useful parts of this project was troubleshooting the IAM configuration.

While moving parts of the existing AWS setup into Terraform, I ran into several IAM errors, including `AccessDenied`, an invalid principal in a trust policy, and a Lambda execution role that could no longer be assumed.

The main issue came from the IAM role path. The Lambda execution role used the `/service-role/` path, and initially that wasn't shown correctly in the Terraform configuration. This caused the role ARN referenced by the cross-account trust policy to no longer match the actual role.

I fixed the issue by checking the role directly through the AWS CLI, correcting the role path in Terraform, rebuilding the trust relationship, and restoring the permissions required by the Lambda execution role.

After fixing the configuration, `terraform plan` returned no changes and the Lambda was again able to assume the Account B role and upload data to S3.

## Key Concepts Demonstrated

### Cross-Account Access

AWS STS allows resources in one AWS account to temporarily assume an IAM role in another account without storing long-term credentials.

### IAM Trust vs. Permissions

The project demonstrates the difference between two important IAM concepts:

- **Trust policies** define who or what can assume a role.
- **Permission policies** define what the role can do after it has been assumed.

### Temporary Credentials

STS generates temporary credentials containing an access key, secret access key, and session token. The Lambda uses these credentials to create an S3 client with the permissions of the Account B role.

### Least-Privilege Access

The cross-account role only grants the permissions required by the application. In this case, the role can upload objects to the designated S3 bucket using `s3:PutObject`.

### Infrastructure as Code

Terraform manages the supporting IAM and S3 infrastructure across both AWS accounts. Terraform state tracks the managed resources, while `terraform plan` can be used to identify configuration drift before changes are applied.