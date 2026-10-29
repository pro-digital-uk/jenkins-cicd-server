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
  description = "Jenkins Docker deployment summary"
  value = var.instance_count > 0 ? "\n=== JENKINS DOCKER DEPLOYMENT ===\n\nURL: http://${module.ec2_docker[0].public_ip}:8080\nInstance ID: ${module.ec2_docker[0].instance_id}\nSSH: ssh -i jenkins-server-key.pem ec2-user@${module.ec2_docker[0].public_ip}\n\nInitial Admin Password:\n  docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword\n" : "No instances created (instance_count = 0)"
}
