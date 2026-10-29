output "jenkins_sg_id" {
  description = "Jenkins security group ID"
  value       = aws_security_group.jenkins.id
}

output "jenkins_sg_name" {
  description = "Jenkins security group name"
  value       = aws_security_group.jenkins.name
}

output "jenkins_sg_arn" {
  description = "Jenkins security group ARN"
  value       = aws_security_group.jenkins.arn
}
