terraform {
  backend "s3" {
    bucket = "alnao-dev-terraform"
    key    = "Esempio18CloudWatchAlarmSNS/terraform.tfstate"
    region = "eu-central-1"
  }
}
