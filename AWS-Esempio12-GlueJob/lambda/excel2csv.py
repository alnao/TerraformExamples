import csv
import fnmatch
import os

import boto3
import openpyxl

source_bucket = os.environ["SourceBucket"]
source_path = os.environ["SourcePath"]
source_pattern = os.environ["SourceFilePattern"]
dest_bucket = os.environ["DestBucket"]
dest_path = os.environ["DestPath"]

C_LOCAL_PATH = "/tmp/"
s3 = boto3.resource("s3")
s3_client = boto3.client("s3")


def lambda_handler(event, context):
    del context
    print(event)

    if "filename" in event:
        file_name = event["filename"]
        s3_key = source_path + "/" + file_name
    else:
        detail = event.get("detail", {})
        obj = detail.get("object", {}) if isinstance(detail, dict) else {}
        s3_key = obj.get("key", "")
        file_name = os.path.basename(s3_key)

    print("Filename: " + file_name)
    if file_name == "":
        return {
            "statusCode": 400,
            "file_name": file_name,
            "numero_righe": "0",
            "flag_processo": False,
        }

    if fnmatch.fnmatch(file_name, source_pattern):
        print("File matched")
        converted_file_name, numero_righe = convert_excel_to_csv(s3_key, file_name)
        return {
            "statusCode": 200,
            "file_name": converted_file_name,
            "numero_righe": str(numero_righe),
            "flag_processo": True #numero_righe % 2 == 0,
        }

    return {
        "statusCode": 400,
        "file_name": file_name,
        "numero_righe": "0",
        "flag_processo": False,
    }


def convert_excel_to_csv(s3_key, file_name):
    print("convert_excel_to_csv: " + s3_key)
    numero_righe = 0

    file_local_path = C_LOCAL_PATH + file_name
    source_bucket_obj = s3.Bucket(source_bucket)
    source_bucket_obj.download_file(s3_key, file_local_path)

    wb = openpyxl.load_workbook(file_local_path)
    ws = wb.worksheets[0]

    csv_filename = os.path.splitext(file_name)[0] + ".csv"
    if "DestFileName" in os.environ and os.environ["DestFileName"] != "":
        csv_filename = os.environ["DestFileName"]

    csv_local_path = C_LOCAL_PATH + csv_filename
    with open(csv_local_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile, delimiter=";")
        for row in ws.rows:
            row_data = [cell.value for cell in row]
            writer.writerow(row_data)
            numero_righe += 1

    destination_key = dest_path + "/" + csv_filename
    s3_client.upload_file(csv_local_path, dest_bucket, destination_key)
    return destination_key, numero_righe
