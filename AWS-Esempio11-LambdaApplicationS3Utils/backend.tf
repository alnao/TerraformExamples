terraform {
  backend "s3" {
    bucket = "terraform-aws-alnao"
    key    = "Esempio11LambdaApplicationS3Utils/terraform.tfstate"
    region = "eu-central-1"
  }
}
