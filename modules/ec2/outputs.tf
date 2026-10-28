output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.jenkins.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.jenkins.private_ip
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_instance.jenkins.public_dns
}

output "private_dns" {
  description = "Private DNS name of the instance"
  value       = aws_instance.jenkins.private_dns
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.ec2_role.arn
}

output "iam_role_name" {
  description = "IAM role name"
  value       = aws_iam_role.ec2_role.name
}
