terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio01bucketS3/terraform.tfstate"
    region = "eu-central-1"
  }
}