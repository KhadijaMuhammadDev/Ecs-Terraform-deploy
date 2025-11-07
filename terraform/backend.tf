terraform {
  backend "s3" {

    bucket = "khadija-tf-state-2025-project"

    key = "dev/terraform.tfstate"

    region = "us-east-1"

    dynamodb_table = "terraform-state-locking"

    encrypt = true
  }
}