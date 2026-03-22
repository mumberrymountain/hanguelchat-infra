# ==========================================
# AWS Load Balancer Controller - IAM (IRSA)
# ==========================================

resource "aws_iam_role" "aws_lb_controller" {
  name = "${var.project_name}-aws-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-aws-lb-controller-role"
  }
}

resource "aws_iam_policy" "aws_lb_controller" {
  name   = "${var.project_name}-aws-lb-controller-policy"
  policy = file("${path.module}/policies/aws-lb-controller-policy.json")

  tags = {
    Name = "${var.project_name}-aws-lb-controller-policy"
  }
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  policy_arn = aws_iam_policy.aws_lb_controller.arn
  role       = aws_iam_role.aws_lb_controller.name
}

# ==========================================
# AWS Load Balancer Controller - Helm
# ==========================================

resource "helm_release" "aws_lb_controller" {
  name = "aws-load-balancer-controller"
  # Helm 프로바이더 3.x에는 repository_config가 없음. 로컬 helm repo(mybitnami 등)와 무관하게 tarball URL로 설치.
  chart     = "https://aws.github.io/eks-charts/aws-load-balancer-controller-1.9.2.tgz"
  namespace = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lb_controller.arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.aws_lb_controller,
  ]
}
