terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio03WebSiteS3/terraform.tfstate"
    region = "eu-central-1"
  }
}
