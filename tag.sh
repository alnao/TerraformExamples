#!/bin/bash
# script per taggare le risorse di default VPC con un tag specifico

TAG_KEY="project"
TAG_VALUE="aws_auto"

#for R in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
#for R in us-east-1 us-east-2 us-west-1 us-west-2 ca-central-1 eu-west-1 eu-west-2 eu-west-3 eu-central-1 eu-north-1 ap-southeast-1 ap-southeast-2 ap-northeast-1 ap-northeast-2 sa-east-1; do
for R in us-east-1 us-east-2 eu-west-1 eu-central-1; do
    VPC=$(aws ec2 describe-vpcs --region "$R" --filters Name=isDefault,Values=true \
        --query 'Vpcs[0].VpcId' --output text)
    [ "$VPC" = "None" ] && continue

    IDS="$VPC $(aws ec2 describe-subnets         --region "$R" --filters Name=vpc-id,Values=$VPC            --query 'Subnets[].SubnetId'            --output text)"
    IDS="$IDS $(aws ec2 describe-route-tables    --region "$R" --filters Name=vpc-id,Values=$VPC            --query 'RouteTables[].RouteTableId'    --output text)"
    IDS="$IDS $(aws ec2 describe-security-groups --region "$R" --filters Name=vpc-id,Values=$VPC            --query 'SecurityGroups[].GroupId'      --output text)"
    IDS="$IDS $(aws ec2 describe-network-acls    --region "$R" --filters Name=vpc-id,Values=$VPC            --query 'NetworkAcls[].NetworkAclId'    --output text)"
    IDS="$IDS $(aws ec2 describe-internet-gateways --region "$R" --filters Name=attachment.vpc-id,Values=$VPC --query 'InternetGateways[].InternetGatewayId' --output text)"

    echo "== $R -> $IDS"
    aws ec2 create-tags --region "$R" --resources $IDS --tags Key=$TAG_KEY,Value=$TAG_VALUE
done