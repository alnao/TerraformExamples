import fnmatch
import json
import os

import boto3

client = boto3.client("stepfunctions")


def _extract_key_from_event(event):
    detail = event.get("detail", {})

    if isinstance(detail.get("object"), dict):
      return detail["object"].get("key")

    request_params = detail.get("requestParameters", {})
    if isinstance(request_params, dict):
      return request_params.get("key")

    return None


def entrypoint(event, context):
    del context
    print("event:", json.dumps(event))

    new_s3_key = _extract_key_from_event(event)
    if not new_s3_key:
        print("No S3 key found in event")
        return

    file_name = os.path.basename(new_s3_key)
    if file_name == "":
        print("Empty filename")
        return

    file_pattern = os.environ["FILE_PATTERN_MATCH"]
    if fnmatch.fnmatch(file_name, file_pattern):
        print(f"File matched: {file_name}")
        client.start_execution(
            stateMachineArn=os.environ["STATE_MACHINE_ARN"],
            input=json.dumps({"filename": file_name}),
        )
