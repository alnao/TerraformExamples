terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio03WebSiteS3/terraform.tfstate"
    region = "eu-central-1"
  }
}
