# DevSecOps-Jenkins-EKS-Pipeline
Built a multi-stage Jenkins pipeline integrating Sonar- Qube (static code analysis), Trivy (filesystem and Docker image security scanning), Docker image build/tag/push, and automated deployment to a Terraform-provisioned EKS cluster with an ALB load balancer; monitored full application stack using Prometheus and Grafana.

# End-to-End DevSecOps CI/CD Pipeline with EKS Deployment

## 🏗️ Architecture Overview
<img width="940" height="660" alt="image" src="https://github.com/user-attachments/assets/f943e7ce-0e2a-48cc-9fc5-4a4054776ab4" />

## 📋 What This Project Does
Automated CI/CD pipeline that takes application code from GitHub 
commit all the way to production deployment on AWS EKS, with 
security scanning, code quality checks, and monitoring.

## 🔧 Tech Stack
| Category        | Tools                              |
|-----------------|------------------------------------|
| CI/CD           | Jenkins                            |
| Security Scan   | Trivy (filesystem + image)         |
| Code Quality    | SonarQube                          |
| Build           | Maven                              |
| Containerization| Docker                             |
| Registry        | Docker Hub (private repo)          |
| Infrastructure  | Terraform                          |
| Orchestration   | AWS EKS (Kubernetes)               |
| Monitoring      | Prometheus + Grafana               |
| Artifact Store  | Nexus                              |

## 🔄 Pipeline Flow
1. Developer pushes code to GitHub
2. Jenkins pipeline triggers automatically via webhook
3. Code compiled with Maven (catches syntax errors early)
4. Unit tests executed
5. Trivy scans filesystem for vulnerabilities
6. SonarQube checks code quality and coverage
7. Maven builds JAR file
8. Docker image built
9. Trivy scans Docker image for CVEs
10. Image pushed to private Docker Hub repository
11. Application deployed to AWS EKS cluster
12. Deployment verified with health check stage
13. Email notification sent on success/failure

## 🏛️ Infrastructure (Terraform)
- VPC with CIDR 
- 2 public subnets 
- Internet Gateway + Route Tables
- EKS Cluster (control plane managed by AWS)
- Node Group with 1 worker node (t3.medium)
- IAM Roles for cluster and node group
- Security Groups for cluster and nodes

## ☸️ Kubernetes Setup
- Deployment with 2 pod replicas
- LoadBalancer service (AWS NLB provisioned automatically)
- Service Account + RBAC for Jenkins to authenticate to EKS
- Image pull secret (regcred) for private Docker Hub access
- App exposed on port 80 → pod port 8080

## 📊 Monitoring
- Prometheus scrapes metrics every 15 seconds
- Grafana dashboards for CPU, memory, request rate
- Blackbox exporter for endpoint uptime monitoring

## 🚀 How to Run This Project

### Prerequisites
- AWS Account with appropriate IAM permissions
- Jenkins server running
- Docker installed
- Terraform installed
- kubectl installed

### Step 1 — Provision EKS with Terraform
cd terraform/
terraform init
terraform plan
terraform apply

### Step 2 — Connect to EKS
aws eks --region eu-central-1 update-kubeconfig --name 

### Step 3 — Configure Jenkins
- Add credentials: Docker Hub, SonarQube token, K8s service account token
- Install plugins: SonarQube Scanner, Kubernetes, Docker Pipeline, Maven

### Step 4 — Run Pipeline
Trigger Jenkins pipeline — it runs all stages automatically

## 📸 Screenshots
- <img width="1280" height="331" alt="image" src="https://github.com/user-attachments/assets/ed38dfc0-6dbf-4ace-98a6-49556a68c6d3" />
- <img width="1280" height="603" alt="image" src="https://github.com/user-attachments/assets/4984bae6-d451-4df9-b169-c2e6ceec48b0" />
- <img width="1280" height="578" alt="image" src="https://github.com/user-attachments/assets/7b538e34-f00b-4054-a519-fda84689d57f" />
- <img width="1280" height="366" alt="image" src="https://github.com/user-attachments/assets/7e647ab1-bc22-47b3-a22c-4b3eb05e7a3f" />
- <img width="1280" height="641" alt="image" src="https://github.com/user-attachments/assets/361f5d92-0552-403e-a882-b5ca6b2143b1" />
- <img width="1280" height="573" alt="image" src="https://github.com/user-attachments/assets/fb6c4794-0866-46e7-91fc-6b3d1c882f85" />

## 🎯 Key Learnings
- Implemented DevSecOps — security scanning at both code and 
  image level, not as an afterthought
- Used Terraform for reproducible infrastructure — entire EKS 
  cluster can be recreated with one command
- RBAC-based Jenkins-to-Kubernetes authentication using service 
  account tokens — no hardcoded credentials
- Private image registry with Kubernetes image pull secrets
