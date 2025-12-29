module "eks" {
  source = "terraform-aws-modules/eks/aws"

  # Keep your version line commented out or remove it (git ref handles it)
  version = "20.8.4"
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  subnet_ids      = module.vpc.private_subnets

  enable_irsa = true

# 1. INSTALL THE DRIVER ADDON
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  tags = {
    cluster = "demo"
  }

  vpc_id = module.vpc.vpc_id

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  cluster_endpoint_public_access_cidrs = [
  "102.88.111.48/32"
  # or 0.0.0.0/0 from anywhere
]

  # [FIX] LOGGING: Enable Control Plane Logging to CloudWatch
  # This meets the "Enable cluster logging" requirement
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # [FIX] SECURITY: Enable KMS Encryption for Kubernetes Secrets (ETCD)
  # This creates a KMS key to encrypt secrets stored in etcd
  # create_kms_key = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    instance_types         = ["t3.medium"]
        # [FIX] SECURITY: Encrypt Node EBS Volumes
    # Ensures the root volume of every worker node is encrypted
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 50
          volume_type           = "gp3"
          iops                  = 3000
          throughput            = 125
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
    # 2. GIVE NODES PERMISSION TO CREATE DISKS
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      # Required if you install the Cluster Autoscaler pod later:
      # AmazonEKSClusterAutoscalerPolicy = "arn:aws:iam::aws:policy/AutoScalingFullAccess" 
      }
    vpc_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  }

  eks_managed_node_groups = {

    node_group = {
      min_size     = 2
      max_size     = 6
      desired_size = 2

      # [FIX] AUTOSCALING: Add Tags for Cluster Autoscaler
      # Without these tags, the autoscaler cannot discover this group.
      tags = {
        "k8s.io/cluster-autoscaler/enabled"                 = "true"
        "k8s.io/cluster-autoscaler/${local.cluster_name}"   = "owned"
      }
    }
  }
}
