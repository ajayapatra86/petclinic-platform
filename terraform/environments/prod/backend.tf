terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-state-ACCOUNT_ID"
    key            = "petclinic/prod/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
