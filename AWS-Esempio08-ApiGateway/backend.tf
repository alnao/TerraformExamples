terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio08ApiGateway/terraform.tfstate"
    region = "eu-central-1"
  }
}
