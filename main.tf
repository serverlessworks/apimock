data "aws_caller_identity" "current" {}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "project" {
  type    = string
  default = "apimock"
}

variable "environment" {
  type    = string
  default = "prd"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "local" {
    path = "./apimock.tfstate"
  }
  #   backend "s3" {
  #     encrypt        = true
  #     region         = var.region
  #     key            = "apimock.tfstate"
  #     dynamodb_table = "terraform-state-lock"
  #   }
}

provider "aws" {
  region = var.region
}

data "template_file" "swagger" {
  template = file("api.yml")
}

resource "aws_api_gateway_rest_api" "api" {
  name = "${var.environment}-${var.project}"
  body = data.template_file.swagger.rendered

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_stage" "api" {
  stage_name    = var.environment
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(aws_api_gateway_rest_api.api.body)
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "api_url" {
  description = "Membership API URL"
  value       = aws_api_gateway_stage.api.invoke_url
}
