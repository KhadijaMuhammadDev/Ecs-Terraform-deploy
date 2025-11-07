# Project: AWS Infrastructure & CI/CD Pipeline with Terraform and Flask

## Overview

This project builds a complete AWS infrastructure using **Terraform** inside **VS Code**, and implements a **CI/CD pipeline** using **GitHub Actions**. The deployed Flask application runs in an **ECS cluster** with images stored in **ECR**, a database hosted on **RDS**, and secure credentials managed by **AWS Secrets Manager**.

---

## Key Components

* **VPC** with Public and Private Subnets
* **Internet Gateway** & **NAT Gateway**
* **Route Tables** configuration
* **ECS Cluster** for container orchestration
* **ECR Repository** for Docker image storage
* **RDS Instance** for the application database
* **Secrets Manager** for secure credential storage
* **Security Groups** with least-privilege rules
* **S3 Bucket** for asset or backup storage

---

## Project Highlights

* Secure and scalable AWS setup
* Automated deployment pipeline using GitHub Actions
* Separation between public and private subnets for better security
* Centralized secret management and safe environment variable handling

---

## Prerequisites

* AWS account with permissions for VPC, EC2, ECS, ECR, RDS, S3, IAM, and Secrets Manager
* Terraform >= 1.0
* AWS CLI configured (`aws configure`) or exported environment variables
* Docker installed
* VS Code (with Terraform and Docker extensions recommended)
* GitHub repository for version control and CI/CD

---

## Project Structure

```
project-root/
├─ terraform/              # Infrastructure as code
│  ├─ modules/             # Separate modules for VPC, ECS, RDS, etc.
│  ├─ envs/                # Environment-specific variables (dev, prod)
│  ├─ main.tf
│  ├─ variables.tf
│  └─ outputs.tf
├─ app/                    # Flask application source
│  ├─ app.py
│  ├─ requirements.txt
│  └─ Dockerfile
├─ .github/
│  └─ workflows/
│     └─ ci-cd.yml         # GitHub Actions workflow file
└─ README.md
```

---

## Infrastructure Deployment — Terraform

1. Initialize and apply Terraform configuration:

```bash
cd terraform
terraform init
terraform validate
terraform plan -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/dev.tfvars"
```

2. Terraform outputs will include: VPC ID, Subnet IDs, ECS Cluster name, ECR URL, RDS endpoint, etc.

> Tip: Use separate `.tfvars` files per environment and **never hardcode secrets** in Terraform code.

---

## Docker Image Build & Push to ECR

1. Log in to ECR:

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com
```

2. Build and tag the image:

```bash
docker build -t myflaskapp:latest ./app
docker tag myflaskapp:latest <aws_account_id>.dkr.ecr.<region>.amazonaws.com/myflaskapp:latest
```

3. Push the image to ECR:

```bash
docker push <aws_account_id>.dkr.ecr.<region>.amazonaws.com/myflaskapp:latest
```

---

## CI/CD Pipeline — GitHub Actions

**Workflow file**: `.github/workflows/ci-cd.yml`

### Steps:

1. **Trigger** — On `push` to `main` or a specific branch
2. **Build** — Install Python dependencies and build Docker image
3. **Test** — Optional unit tests stage
4. **Login to AWS & ECR** — Using `aws-actions/configure-aws-credentials` and `docker/login-action`
5. **Push Image** — Push the image to ECR
6. **Deploy** — Update ECS Service with the new image

### Example Snippet:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1

- name: Login to ECR
  uses: docker/login-action@v2
  with:
    registry: ${{ env.ECR_REGISTRY }}
    username: AWS
    password: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

- name: Build, tag, and push image
  run: |
    docker build -t ${{ env.ECR_REPOSITORY }}:${{ github.sha }} ./app
    docker tag ${{ env.ECR_REPOSITORY }}:${{ github.sha }} ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
    docker push ${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}

- name: Deploy to ECS
  run: |
    aws ecs update-service \
      --cluster ${{ env.ECS_CLUSTER }} \
      --service ${{ env.ECS_SERVICE }} \
      --force-new-deployment
```

---

## Secrets and Environment Variables

Store sensitive information safely:

* In **AWS Secrets Manager** for runtime use
* In **GitHub Secrets** for CI/CD, including:

  * `AWS_ACCESS_KEY_ID`
  * `AWS_SECRET_ACCESS_KEY`
  * `AWS_REGION`
  * `ECR_REGISTRY`
  * `ECR_REPOSITORY`
  * `ECS_CLUSTER`
  * `ECS_SERVICE`

---

## Running Flask App Locally

```bash
export FLASK_APP=app.py
export DATABASE_URL="postgresql://user:pass@localhost:5432/dbname"
pip install -r app/requirements.txt
flask run --host=0.0.0.0 --port=5000
```

Or using Docker:

```bash
docker build -t myflaskapp:local ./app
docker run -p 5000:5000 myflaskapp:local
```

---

## Security Best Practices

* Keep RDS in private subnets
* Restrict inbound traffic with precise Security Group rules
* Rotate AWS keys regularly
* Enable CloudWatch logging and RDS snapshots
* Use HTTPS and encrypted connections (TLS)

---

## Common Issues

* **ECR Login Failure:** Check IAM permissions and correct region.
* **ECS Deployment Not Updating:** Ensure the task definition uses the latest image tag.
* **RDS Connection Error:** Verify subnet and security group access.

---

## Future Improvements

* Add Blue/Green or Canary deployments
* Implement autoscaling for ECS
* Separate environments via Terraform workspaces
* Integrate automated testing in CI/CD

---

## References

* [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
* [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
* [GitHub Actions for AWS](https://github.com/aws-actions)

---

## Author

Developed by **Khadija Mohammed** — Infrastructure as Code, Flask, and AWS CI/CD.
