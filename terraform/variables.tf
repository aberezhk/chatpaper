# Variables for terraform

# region of deployment
variable "region" {
 description = "region"
 type = string
 default = "eu-central-1"
}

# name of the ecr repo
variable "ecr" {
 description = "ecr repo name"
 type = string
 default = "chat-paper-ecr-repo"
}

# aws account id
# enter value when terraform apply is executed
variable "account_id" {
 description = "account id"
 type = string
}

# OpenAI api key
# enter value when terraform apply is executed
variable "api_key" {
 description = "OpenAI API key"
 type = string
}


