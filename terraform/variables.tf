variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public Subnet CIDR 블록"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr_2" {
  description = "Public Subnet 2 CIDR 블록"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr" {
  description = "Private Subnet CIDR 블록"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "가용 영역"
  type        = string
  default     = "ap-northeast-2a"
}

variable "availability_zone_2" {
  description = "가용 영역 2"
  type        = string
  default     = "ap-northeast-2b"
}

variable "ec2_instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t2.small"
}

variable "ec2_ami" {
  description = "EC2 AMI ID"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM 인증서 ARN"
  type        = string
  sensitive   = true
}

variable "target_group_port" {
  description = "Target Group 포트 (nginx Ingress Controller NodePort와 일치해야 함)"
  type        = number
  default     = 30080
}

variable "ec2_iam_role_name" {
  description = "EC2 인스턴스에 연결할 IAM 프로필"
  type        = string
  sensitive   = true
}

variable "ebs_volume_size" {
  description = "EBS 볼륨 크기 (GB)"
  type        = number
  default     = 20
}

variable "ebs_volume_type" {
  description = "EBS 볼륨 타입"
  type        = string
  default     = "gp3"
}

variable "nat_instance_type" {
  description = "NAT 인스턴스 타입"
  type        = string
  default     = "t3.nano"
}