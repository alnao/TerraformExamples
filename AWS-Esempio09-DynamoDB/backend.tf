terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio09DynamoDB/terraform.tfstate"
    region = "eu-central-1"
  }
}
