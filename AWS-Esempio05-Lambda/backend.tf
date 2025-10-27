terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio05Lambda/terraform.tfstate"
    region = "eu-central-1"
  }
}
