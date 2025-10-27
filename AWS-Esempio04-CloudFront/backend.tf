terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio04CloudFront/terraform.tfstate"
    region = "eu-central-1"
  }
}
