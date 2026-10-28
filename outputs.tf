output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "jenkins_security_group_id" {
  description = "Jenkins security group ID"
  value       = module.security_groups.jenkins_sg_id
}

output "key_pair_name" {
  description = "Key pair name"
  value       = module.key_pair.key_pair_name
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.s3.bucket_arn
}

output "ec2_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ec2_instance_public_ip" {
  description = "Jenkins EC2 instance public IP"
  value       = module.ec2.public_ip
}

output "ec2_instance_private_ip" {
  description = "Jenkins EC2 instance private IP"
  value       = module.ec2.private_ip
}

output "jenkins_url" {
  description = "Jenkins server URL"
  value       = var.enable_public_ip ? "http://${module.ec2.public_ip}:8080" : "Jenkins server in private subnet"
}

output "ec2_iam_role_arn" {
  description = "EC2 IAM role ARN"
  value       = module.ec2.iam_role_arn
}
