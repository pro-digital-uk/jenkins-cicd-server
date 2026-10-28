output "key_pair_name" {
  description = "Key pair name"
  value       = aws_key_pair.main.key_name
}

output "key_pair_id" {
  description = "Key pair ID"
  value       = aws_key_pair.main.id
}

output "private_key_path" {
  description = "Path to the private key file"
  value       = local_file.private_key.filename
}
