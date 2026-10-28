resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = tls_private_key.main.public_key_openssh

  tags = merge(
    var.tags,
    {
      Name = var.key_name
    }
  )
}

resource "local_file" "private_key" {
  filename             = "${path.module}/../../${var.key_name}.pem"
  content              = tls_private_key.main.private_key_pem
  file_permission      = "0600"
  directory_permission = "0755"
}
