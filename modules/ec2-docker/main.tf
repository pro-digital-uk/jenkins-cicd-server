data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.instance_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "s3_access" {
  name = "${var.instance_name}-s3-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  count                  = var.instance_count

  associate_public_ip_address = var.associate_public_ip

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    S3_BUCKET_NAME = var.s3_bucket_name
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true
  }

  monitoring = true

  tags = merge(
    var.tags,
    {
      Name = var.instance_name
    }
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [user_data]
  }

  depends_on = [aws_iam_instance_profile.ec2_profile]
}

resource "aws_ebs_volume" "jenkins_data" {
  count             = var.instance_count
  availability_zone = aws_instance.jenkins[count.index].availability_zone
  size              = 20
  type              = "gp3"
  encrypted         = true

  tags = merge(
    var.tags,
    {
      Name = "${var.instance_name}-data"
    }
  )
}

resource "aws_volume_attachment" "jenkins_data" {
  count           = var.instance_count
  device_name     = "/dev/sdf"
  volume_id       = aws_ebs_volume.jenkins_data[count.index].id
  instance_id     = aws_instance.jenkins[count.index].id
  skip_destroy    = true
}
