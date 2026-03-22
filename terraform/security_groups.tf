resource "aws_security_group" "nat" {
  name        = "${var.project_name}-nat-sg"
  description = "Security group for NAT instance"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-nat-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_private" {
  security_group_id = aws_security_group.nat.id
  cidr_ipv4         = var.private_subnet_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_private_2" {
  security_group_id = aws_security_group.nat.id
  cidr_ipv4         = var.private_subnet_cidr_2
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "nat_all" {
  security_group_id = aws_security_group.nat.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
