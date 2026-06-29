# ============================================================
#  EKS Cluster — End-to-End DevSecOps Project
#  Provisions: VPC, Subnets, IGW, Route Tables,
#              Security Groups, EKS Cluster, Node Group,
#              IAM Roles and Policies
# ============================================================

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ── Remote Backend ─────────────────────────────────────────
  # Uncomment and configure before running in a team environment
  # backend "s3" {
  #   bucket         = "<your-state-bucket-name>"
  #   key            = "eks/terraform.tfstate"
  #   region         = "<your-region>"
  #   dynamodb_table = "<your-lock-table-name>"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
#  NETWORKING
# ============================================================

# ── VPC ──────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ── Public Subnets ────────────────────────────────────────────
# Two subnets across two AZs for high availability
# cidrsubnet(vpc_cidr, 4, index) gives /24 subnets:
#   index 0 → 10.240.0.0/24
#   index 1 → 10.240.1.0/24
resource "aws_subnet" "public" {
  count = var.subnet_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${var.project_name}-public-subnet-${count.index}"
    Project                                         = var.project_name
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# ── Internet Gateway ──────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ── Route Table ───────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

# ── Route Table Associations ──────────────────────────────────
resource "aws_route_table_association" "public" {
  count          = var.subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================================
#  SECURITY GROUPS
# ============================================================

# ── Cluster Security Group ────────────────────────────────────
# Allows worker nodes to communicate with the EKS control plane
resource "aws_security_group" "cluster" {
  vpc_id      = aws_vpc.main.id
  description = "EKS cluster security group — controls access to control plane"

  ingress {
    description     = "Allow worker nodes to reach control plane API"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.node.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-cluster-sg"
    Project = var.project_name
  }
}

# ── Node Security Group ───────────────────────────────────────
# NOTE: Inbound 0.0.0.0/0 is open for this learning project.
# In production, restrict to specific CIDRs and ports only.
resource "aws_security_group" "node" {
  vpc_id      = aws_vpc.main.id
  description = "EKS worker node security group"

  ingress {
    description = "Allow all inbound — restrict in production"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-node-sg"
    Project = var.project_name
  }
}

# ============================================================
#  SSH KEY PAIR
# ============================================================

# ── EC2 Key Pair for Node Access ──────────────────────────────
# Public key is passed via TF_VAR_ssh_public_key env variable
# Never hardcode the actual key value here
resource "aws_key_pair" "eks_nodes" {
  count      = var.ssh_public_key != "" ? 1 : 0
  key_name   = "${var.project_name}-eks-nodes"
  public_key = var.ssh_public_key

  tags = {
    Name    = "${var.project_name}-eks-key"
    Project = var.project_name
  }
}

# ============================================================
#  EKS CLUSTER
# ============================================================

resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids         = aws_subnet.public[*].id
    security_group_ids = [aws_security_group.cluster.id]
  }

  # Ensure IAM role is ready before cluster creation
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  tags = {
    Name    = var.eks_cluster_name
    Project = var.project_name
  }
}

# ============================================================
#  EKS NODE GROUP
# ============================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  instance_types = [var.node_instance_type]

  # SSH access — only attached if ssh_public_key is provided
  dynamic "remote_access" {
    for_each = var.ssh_public_key != "" ? [1] : []
    content {
      ec2_ssh_key               = aws_key_pair.eks_nodes[0].key_name
      source_security_group_ids = [aws_security_group.node.id]
    }
  }

  # Ensure IAM roles are ready before node group creation
  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_registry_policy,
  ]

  tags = {
    Name    = var.node_group_name
    Project = var.project_name
  }
}

# ============================================================
#  IAM — CLUSTER ROLE
# ============================================================

resource "aws_iam_role" "cluster" {
  name        = "${var.project_name}-cluster-role"
  description = "IAM role for EKS control plane"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-cluster-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ============================================================
#  IAM — NODE GROUP ROLE
# ============================================================

resource "aws_iam_role" "node_group" {
  name        = "${var.project_name}-node-group-role"
  description = "IAM role for EKS worker nodes"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.project_name}-node-group-role"
    Project = var.project_name
  }
}

# Three policies required for worker nodes:
# 1. Worker node general permissions
# 2. CNI plugin — pod networking
# 3. ECR read — pull container images

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_registry_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
