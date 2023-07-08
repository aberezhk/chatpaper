terraform {
 required_providers {
     aws = {
         source = "hashicorp/aws"
         version = "~> 4.0"
     }
 }
}

provider "aws" {
 region = var.region
 account_id = var.account_id
 ecr = var.ecr
 api_key = var.api_key
}