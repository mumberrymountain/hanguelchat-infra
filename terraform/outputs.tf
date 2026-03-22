output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.main.name
}

output "cluster_version" {
  description = "EKS 클러스터 버전"
  value       = aws_eks_cluster.main.version
}

output "node_group_role_arn" {
  description = "EKS 노드 그룹 IAM Role ARN"
  value       = aws_iam_role.eks_node.arn
}

output "configure_kubectl" {
  description = "kubectl 설정 명령어"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "aws_region" {
  description = "AWS 리전 (scripts/install-k8s-addons.* 용)"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "aws_lb_controller_role_arn" {
  description = "AWS Load Balancer Controller IRSA Role ARN"
  value       = aws_iam_role.aws_lb_controller.arn
}

output "acm_certificate_arn" {
  description = "ACM 인증서 ARN (ingress-nginx NLB TLS)"
  value       = var.acm_certificate_arn
  sensitive   = true
}
