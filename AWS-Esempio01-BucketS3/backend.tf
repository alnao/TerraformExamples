terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio01bucketS3/terraform.tfstate"
    region = "eu-central-1"
  }
}