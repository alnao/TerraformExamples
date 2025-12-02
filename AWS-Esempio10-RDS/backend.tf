terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio10RDS/terraform.tfstate"
    region = "eu-central-1"
  }
}
