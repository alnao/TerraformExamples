terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio06EventBridge/terraform.tfstate"
    region = "eu-central-1"
  }
}
