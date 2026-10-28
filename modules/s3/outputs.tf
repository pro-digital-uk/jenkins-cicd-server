output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.jenkins.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.jenkins.arn
}

output "bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.jenkins.bucket_regional_domain_name
}
