# Quick Reference - AWS CLI Commands

## Setup Iniziale

### 1. Crea Chiave SFTP
```bash
# Genera chiave RSA
ssh-keygen -t rsa -b 2048 -m PEM -f sftp_key -N ""

# Upload a SSM
aws ssm put-parameter \
  --name "/esempio-11/sftp/private-key" \
  --value file://sftp_key \
  --type "SecureString" \
  --region eu-central-1
```

### 2. Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply -auto-approve

# Save API URL
API_URL=$(terraform output -raw api_gateway_url)
echo $API_URL
```

## S3 Operations

### Upload File
```bash
# Direct upload
aws s3 cp myfile.txt s3://BUCKET_NAME/

# Via presigned URL
PRESIGNED=$(curl -s -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt"}' | jq -r .presigned_url)

curl -X PUT "$PRESIGNED" --upload-file test.txt
```

### List Objects
```bash
aws s3 ls s3://BUCKET_NAME/ --recursive
```

### Download File
```bash
aws s3 cp s3://BUCKET_NAME/file.txt .
```

## API Gateway Calls

### Generate Presigned URL
```bash
curl -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename":"upload.txt","expires_in":3600}'
```

### Extract ZIP
```bash
curl -X POST $API_URL/extract-zip \
  -H "Content-Type: application/json" \
  -d '{"zip_key":"archive.zip"}'
```

### Excel to CSV
```bash
curl -X POST $API_URL/excel-to-csv \
  -H "Content-Type: application/json" \
  -d '{"excel_key":"data.xlsx","sheet_name":"Sheet1"}'
```

### Upload to RDS
```bash
curl -X POST $API_URL/upload-to-rds \
  -H "Content-Type: application/json" \
  -d '{"csv_key":"data.csv","table_name":"imported_data"}'
```

### SFTP Send
```bash
curl -X POST $API_URL/sftp-send \
  -H "Content-Type: application/json" \
  -d '{
    "s3_key":"file.txt",
    "sftp_host":"sftp.example.com",
    "sftp_username":"user",
    "sftp_remote_path":"/upload/file.txt"
  }'
```

### List Files
```bash
# Last 1 day (default)
curl $API_URL/files

# Last 7 days
curl "$API_URL/files?days=7&limit=50"
```

### Search Files
```bash
curl "$API_URL/files/search?name=test&limit=20"
```

## DynamoDB Operations

### Query Logs by Operation
```bash
aws dynamodb query \
  --table-name esempio-11-logs \
  --index-name OperationIndex \
  --key-condition-expression "operation = :op" \
  --expression-attribute-values '{":op":{"S":"presigned_url"}}' \
  --limit 10
```

### Scan All Logs
```bash
aws dynamodb scan \
  --table-name esempio-11-logs \
  --limit 20
```

### Query Files by Scan Date
```bash
aws dynamodb query \
  --table-name esempio-11-scan \
  --index-name ScanDateIndex \
  --key-condition-expression "scan_date = :date" \
  --expression-attribute-values '{":date":{"S":"2025-12-02"}}'
```

### Get Specific File
```bash
aws dynamodb get-item \
  --table-name esempio-11-scan \
  --key '{"file_key":{"S":"test.txt"}}'
```

## RDS Operations

### Get Credentials
```bash
# Get secret ARN
SECRET_ARN=$(terraform output -raw rds_secret_arn)

# Read credentials
aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --query SecretString \
  --output text | jq .

# Extract values
ENDPOINT=$(terraform output -raw rds_cluster_endpoint)
DB_NAME=$(terraform output -raw rds_database_name)
```

### Connect to MySQL
```bash
# Get password
PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --query SecretString \
  --output text | jq -r .password)

# Connect
mysql -h $ENDPOINT -u admin -p$PASSWORD $DB_NAME
```

### MySQL Queries
```sql
-- Show databases
SHOW DATABASES;

-- Use database
USE esempio11db;

-- Show tables
SHOW TABLES;

-- Query data
SELECT * FROM imported_data LIMIT 10;

-- Table info
DESCRIBE imported_data;
```

## Lambda Operations

### Invoke Lambda Directly
```bash
# Invoke presigned_url
aws lambda invoke \
  --function-name esempio-11-presigned-url \
  --payload '{"body":"{\"filename\":\"test.txt\"}"}' \
  response.json

cat response.json | jq .
```

### View Logs
```bash
# Get latest log stream
aws logs describe-log-streams \
  --log-group-name /aws/lambda/esempio-11-presigned-url \
  --order-by LastEventTime \
  --descending \
  --limit 1

# View logs
aws logs tail /aws/lambda/esempio-11-presigned-url --follow
```

### Trigger S3 Scan Manually
```bash
aws lambda invoke \
  --function-name esempio-11-s3-scan \
  --payload '{}' \
  response.json
```

## EventBridge Operations

### List Rules
```bash
aws events list-rules --name-prefix esempio-11
```

### View Rule Details
```bash
aws events describe-rule --name esempio-11-s3-scan-schedule
```

### Disable/Enable Schedule
```bash
# Disable
aws events disable-rule --name esempio-11-s3-scan-schedule

# Enable
aws events enable-rule --name esempio-11-s3-scan-schedule
```

## CloudWatch Operations

### View Log Groups
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/esempio-11
```

### Tail Multiple Logs
```bash
aws logs tail /aws/lambda/esempio-11-presigned-url \
             /aws/lambda/esempio-11-extract-zip \
             --follow
```

### Query Logs (Insights)
```bash
aws logs start-query \
  --log-group-name /aws/lambda/esempio-11-presigned-url \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc'
```

### View Alarms
```bash
aws cloudwatch describe-alarms --alarm-name-prefix esempio-11
```

### Get Metrics
```bash
# Lambda invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=esempio-11-presigned-url \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## SSM Parameter Store

### View Parameter
```bash
aws ssm get-parameter \
  --name "/esempio-11/sftp/private-key" \
  --with-decryption \
  --query Parameter.Value \
  --output text
```

### Update Parameter
```bash
aws ssm put-parameter \
  --name "/esempio-11/sftp/private-key" \
  --value file://new_sftp_key \
  --type "SecureString" \
  --overwrite
```

## Testing & Debugging

### Complete Workflow Test
```bash
#!/bin/bash
set -e

# 1. Generate presigned URL
echo "1. Generating presigned URL..."
PRESIGNED=$(curl -s -X POST $API_URL/presigned-url \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.zip"}' | jq -r .presigned_url)

# 2. Upload test ZIP
echo "2. Uploading test.zip..."
curl -X PUT "$PRESIGNED" --upload-file test.zip

# 3. Wait for processing
echo "3. Waiting for EventBridge processing..."
sleep 15

# 4. List files
echo "4. Listing files..."
curl "$API_URL/files?days=1" | jq .

# 5. Search files
echo "5. Searching for 'test'..."
curl "$API_URL/files/search?name=test" | jq .

echo "✅ Workflow test completed!"
```

### Check Resource Status
```bash
# S3 Bucket
aws s3api head-bucket --bucket BUCKET_NAME

# DynamoDB Tables
aws dynamodb describe-table --table-name esempio-11-logs
aws dynamodb describe-table --table-name esempio-11-scan

# RDS Cluster
aws rds describe-db-clusters --db-cluster-identifier esempio-11-aurora

# Lambda Functions
aws lambda list-functions --query 'Functions[?contains(FunctionName, `esempio-11`)].FunctionName'

# API Gateway
aws apigateway get-rest-apis --query 'items[?name==`esempio-11-api`]'
```

## Cleanup

### Empty S3 Bucket
```bash
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
aws s3 rm s3://$BUCKET_NAME --recursive
```

### Delete SSM Parameter
```bash
aws ssm delete-parameter --name "/esempio-11/sftp/private-key"
```

### Destroy Infrastructure
```bash
terraform destroy -auto-approve
```

## Monitoring Commands

### Watch Lambda Metrics
```bash
watch -n 5 'aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=esempio-11-presigned-url \
  --start-time $(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum \
  --query "Datapoints[0].Sum"'
```

### Watch API Gateway Metrics
```bash
watch -n 5 'aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name Count \
  --dimensions Name=ApiName,Value=esempio-11-api \
  --start-time $(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum'
```

## Cost Tracking

### Get Cost by Tag
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=TAG,Key=Project \
  --filter file://filter.json

# filter.json:
{
  "Tags": {
    "Key": "Project",
    "Values": ["esempio-11"]
  }
}
```

## Useful Aliases

Add to `.bashrc` or `.zshrc`:

```bash
# Esempio 11 aliases
alias e11-api='echo $(terraform output -raw api_gateway_url)'
alias e11-logs='aws logs tail /aws/lambda/esempio-11-presigned-url --follow'
alias e11-s3='aws s3 ls s3://$(terraform output -raw s3_bucket_name)/ --recursive'
alias e11-rds='mysql -h $(terraform output -raw rds_cluster_endpoint) -u admin -p'
alias e11-scan='aws lambda invoke --function-name esempio-11-s3-scan response.json && cat response.json'
```

## Environment Variables

```bash
# Export common variables
export API_URL=$(terraform output -raw api_gateway_url)
export BUCKET_NAME=$(terraform output -raw s3_bucket_name)
export RDS_ENDPOINT=$(terraform output -raw rds_cluster_endpoint)
export SECRET_ARN=$(terraform output -raw rds_secret_arn)

# Save to file
cat > .env << EOF
API_URL=$API_URL
BUCKET_NAME=$BUCKET_NAME
RDS_ENDPOINT=$RDS_ENDPOINT
SECRET_ARN=$SECRET_ARN
EOF

# Load from file
source .env
```
