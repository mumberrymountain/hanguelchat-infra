data "aws_iam_instance_profile" "ec2" {
  name = var.ec2_iam_role_name
}

resource "aws_instance" "main" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = data.aws_iam_instance_profile.ec2.name

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_size           = var.ebs_volume_size
    volume_type           = var.ebs_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  depends_on = [aws_instance.nat, aws_eip.nat_instance]

  user_data = file("${path.module}/scripts/ec2-init.sh")

  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

