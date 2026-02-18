variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnets_cidr" {
  type    = list(string)
}

variable "private_subnets_cidr" {
  type    = list(string)
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    Project = "llm-test"
    Env     = "dev"
  }
}