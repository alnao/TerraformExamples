terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio17Textract/terraform.tfstate"
    region = "eu-central-1"
  }
}
