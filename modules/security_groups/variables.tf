variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "jenkins_port" {
  description = "Jenkins server port"
  type        = number
  default     = 8080
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
