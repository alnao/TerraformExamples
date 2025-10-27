terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio09DynamoDB/terraform.tfstate"
    region = "eu-central-1"
  }
}
