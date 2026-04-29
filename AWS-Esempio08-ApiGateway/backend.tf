terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio08ApiGateway/terraform.tfstate"
    region = "eu-central-1"
  }
}
