terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio04CloudFront/terraform.tfstate"
    region = "eu-central-1"
  }
}
