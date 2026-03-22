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

variable "private_subnet_cidr_2" {
  description = "Private Subnet 2 CIDR 블록"
  type        = string
  default     = "10.0.4.0/24"
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

variable "acm_certificate_arn" {
  description = "ACM 인증서 ARN (NLB TLS 종료에 사용)"
  type        = string
  sensitive   = true
}

variable "nat_instance_type" {
  description = "NAT 인스턴스 타입"
  type        = string
  default     = "t3.nano"
}

variable "nat_instance_ami" {
  description = "NAT 인스턴스 AMI ID"
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS 클러스터 버전"
  type        = string
  default     = "1.30"
}

variable "eks_node_instance_type" {
  description = "EKS 워커 노드 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_disk_size" {
  description = "EKS 워커 노드 디스크 크기 (GB)"
  type        = number
  default     = 20
}

variable "eks_node_desired_size" {
  description = "EKS 노드 그룹 Desired 크기"
  type        = number
  default     = 4
}

variable "eks_node_min_size" {
  description = "EKS 노드 그룹 최소 크기"
  type        = number
  default     = 4
}

variable "eks_node_max_size" {
  description = "EKS 노드 그룹 최대 크기"
  type        = number
  default     = 6
}
