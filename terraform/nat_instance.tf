resource "aws_instance" "nat" {
  ami                         = var.ec2_ami
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  source_dest_check           = false
  associate_public_ip_address = true

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-nat.conf
    sysctl -p /etc/sysctl.d/99-nat.conf

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent

    iptables -t nat -F
    iptables -F FORWARD
    iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -j ACCEPT

    netfilter-persistent save
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-nat-instance"
  }

  depends_on = [aws_internet_gateway.main]

  lifecycle {
    ignore_changes = [ami]
  }
}

