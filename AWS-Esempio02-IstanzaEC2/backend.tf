terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio02IstanzaEC2/terraform.tfstate"
    region = "eu-central-1"
  }
}
