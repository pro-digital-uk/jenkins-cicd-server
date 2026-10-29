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

# Direct Installation Outputs
output "ec2_direct_instance_id" {
  description = "Jenkins Direct Installation EC2 instance ID"
  value       = try(module.ec2[0].instance_id, null)
}

output "ec2_direct_public_ip" {
  description = "Jenkins Direct Installation public IP"
  value       = try(module.ec2[0].public_ip, null)
}

output "jenkins_direct_url" {
  description = "Jenkins Direct Installation URL"
  value       = var.enable_public_ip && var.instance_count > 0 ? "http://${module.ec2[0].public_ip}:8080" : "Instance not created"
}

# Docker Installation Outputs
output "ec2_docker_instance_id" {
  description = "Jenkins Docker EC2 instance ID"
  value       = try(module.ec2_docker[0].instance_id, null)
}

output "ec2_docker_public_ip" {
  description = "Jenkins Docker public IP"
  value       = try(module.ec2_docker[0].public_ip, null)
}

output "jenkins_docker_url" {
  description = "Jenkins Docker URL"
  value       = var.enable_public_ip && var.instance_count > 0 ? "http://${module.ec2_docker[0].public_ip}:8080" : "Instance not created"
}

# Summary
output "deployment_summary" {
  description = "Summary of both deployments"
  value = var.instance_count > 0 ? "\n=== JENKINS DUAL DEPLOYMENT ===\n\n[1] DIRECT INSTALLATION\n    URL: http://${module.ec2[0].public_ip}:8080\n    Instance ID: ${module.ec2[0].instance_id}\n    SSH: ssh -i jenkins-server-key.pem ec2-user@${module.ec2[0].public_ip}\n\n[2] DOCKER CONTAINER\n    URL: http://${module.ec2_docker[0].public_ip}:8080\n    Instance ID: ${module.ec2_docker[0].instance_id}\n    SSH: ssh -i jenkins-server-key.pem ec2-user@${module.ec2_docker[0].public_ip}\n" : "No instances created (instance_count = 0)"
}
