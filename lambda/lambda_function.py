import boto3
import os
import json
import urllib.request
from datetime import datetime, timezone

# Account B role that this Lambda will assume
ROLE_ARN = os.environ["ROLE_ARN"]

# S3 bucket in Account B
BUCKET_NAME = os.environ["BUCKET_NAME"]


def lambda_handler(event, context):

    # 1. Get the current ISS location from the public API
    url = "http://api.open-notify.org/iss-now.json"

    with urllib.request.urlopen(url) as response:
        iss_data = json.loads(response.read().decode())

    # 2. Ask AWS STS to assume the role in Account B
    sts = boto3.client("sts")

    assumed_role = sts.assume_role(
        RoleArn=ROLE_ARN,
        RoleSessionName="ISSLocationSession"
    )

    credentials = assumed_role["Credentials"]

    # 3. Create an S3 client using the TEMPORARY credentials
    s3 = boto3.client(
        "s3",
        aws_access_key_id=credentials["AccessKeyId"],
        aws_secret_access_key=credentials["SecretAccessKey"],
        aws_session_token=credentials["SessionToken"]
    )

    # 4. Create a unique filename
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d-%H-%M-%S")
    filename = f"iss-location-{timestamp}.json"

    # 5. Upload the ISS data into Account B's bucket
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=filename,
        Body=json.dumps(iss_data, indent=2),
        ContentType="application/json"
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "ISS location successfully uploaded to Account B",
            "file": filename
        })
    }