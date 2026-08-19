import json
import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError


autoscaling = boto3.client("autoscaling")
ssm = boto3.client("ssm")


def lambda_handler(event, context):
    asg_name = os.environ["ASG_NAME"]
    default_desired = int(os.environ.get("DEFAULT_DESIRED", "2"))
    parameter_name = os.environ["PARAMETER_NAME"]

    try:
        response = ssm.get_parameter(Name=parameter_name)
        expires_at_raw = response["Parameter"]["Value"]
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") == "ParameterNotFound":
            return {
                "statusCode": 200,
                "body": json.dumps(
                    {
                        "message": "No temporary scaling active",
                        "asg": asg_name,
                    }
                ),
            }
        raise

    expires_at = datetime.fromisoformat(expires_at_raw)
    now = datetime.now(timezone.utc)

    if now >= expires_at:
        autoscaling.set_desired_capacity(
            AutoScalingGroupName=asg_name,
            DesiredCapacity=default_desired,
            HonorCooldown=False,
        )

        ssm.delete_parameter(Name=parameter_name)

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Temporary scaling removed",
                    "asg": asg_name,
                    "desired_capacity": default_desired,
                }
            ),
        }

    remaining = (expires_at - now).total_seconds()

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Temporary scaling still active",
                "asg": asg_name,
                "seconds_remaining": int(remaining),
            }
        ),
    }
