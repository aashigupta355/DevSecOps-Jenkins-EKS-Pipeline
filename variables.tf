variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resource names"
  type        = string
  default     = "my-eks"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.240.0.0/20"
}

variable "availability_zones" {
  description = "List of availability zones to use for subnets"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "subnet_count" {
  description = "Number of public subnets to create"
  type        = number
  default     = 2
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "my-eks-node-group"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 node access. Set via TF_VAR_ssh_public_key env variable — never hardcode here"
  type        = string
  sensitive   = true
  default     = ""
}
