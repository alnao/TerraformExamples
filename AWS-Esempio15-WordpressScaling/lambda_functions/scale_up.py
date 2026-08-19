import json
import os
from datetime import datetime, timedelta, timezone

import boto3


autoscaling = boto3.client("autoscaling")
ssm = boto3.client("ssm")


def lambda_handler(event, context):
    asg_name = os.environ["ASG_NAME"]
    default_desired = int(os.environ.get("DEFAULT_DESIRED", "2"))
    temp_desired = int(os.environ.get("TEMP_DESIRED", "3"))
    duration_hours = int(os.environ.get("DURATION_HOURS", "4"))
    parameter_name = os.environ["PARAMETER_NAME"]
    max_capacity = int(os.environ.get("MAX_CAPACITY", "4"))

    new_desired = min(temp_desired, max_capacity)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=duration_hours)

    autoscaling.update_auto_scaling_group(
        AutoScalingGroupName=asg_name,
        MinSize=default_desired,
        MaxSize=max_capacity,
        DesiredCapacity=new_desired,
    )

    ssm.put_parameter(
        Name=parameter_name,
        Value=expires_at.isoformat(),
        Type="String",
        Overwrite=True,
    )

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Temporary scaling applied",
                "asg": asg_name,
                "desired_capacity": new_desired,
                "expires_at": expires_at.isoformat(),
            }
        ),
    }
