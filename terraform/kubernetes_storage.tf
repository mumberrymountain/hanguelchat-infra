# EKS: EBS CSI 드라이버(eks.tf 애드온)용 gp3 기본 StorageClass
# prod 매니페스트의 PVC는 storageClassName: gp3 사용

resource "kubernetes_storage_class_v1" "ebs_gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

resource "kubernetes_annotations" "gp2_not_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }

  force = true

  depends_on = [aws_eks_addon.ebs_csi]
}
