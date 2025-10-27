terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio06EventBridge/terraform.tfstate"
    region = "eu-central-1"
  }
}
