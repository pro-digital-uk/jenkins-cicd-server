output "instance_id" {
  description = "EC2 instance ID"
  value       = try(aws_instance.jenkins[0].id, null)
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = try(aws_instance.jenkins[0].public_ip, null)
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = try(aws_instance.jenkins[0].private_ip, null)
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = try(aws_instance.jenkins[0].public_dns, null)
}

output "private_dns" {
  description = "Private DNS name of the instance"
  value       = try(aws_instance.jenkins[0].private_dns, null)
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.ec2_role.arn
}

output "iam_role_name" {
  description = "IAM role name"
  value       = aws_iam_role.ec2_role.name
}
