<!-- Badges/Icons -->
<p align="center">
  <img src="https://img.shields.io/badge/Node.js-339933?logo=node.js&logoColor=white" height="28"/>
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white" height="28"/>
  <img src="https://img.shields.io/badge/AWS-232F3E?logo=amazon-aws&logoColor=white" height="28"/>
  <img src="https://img.shields.io/badge/Terraform-623CE4?logo=terraform&logoColor=white" height="28"/>
</p>

# TODO API – Node.js, PostgreSQL, Docker & AWS

> **This is a simple TODO API project focused on demonstrating modern Infrastructure as Code (IaC) using Terraform.**

- The main goal is to show how to provision a secure, production-ready environment on AWS using Terraform.
- All infrastructure (network, security, compute, database, load balancer) is managed as code.
- The API is intentionally simple to keep the focus on the infrastructure.

---

## Available Endpoints

- `GET /todos` – List all TODOs
- `POST /todos` – Create a new TODO

**Payload for creating a TODO:**
```json
{
  "title": "title",
  "description": "description",
  "completed": false
}
```

---

## Getting Started with AWS

1. **Create a Free AWS Account**
   - Go to [aws.amazon.com/free](https://aws.amazon.com/free/) and sign up for a free account.
   - As of today, AWS offers **$200 in free credits** for new accounts (subject to change, check the AWS Free Tier page for current offers).

2. **Create an IAM User**
   - In the AWS Console, go to **IAM > Users > Add users**.
   - Give programmatic access and attach the policies: `AmazonEC2FullAccess`, `AmazonECS_FullAccess`, `AmazonRDSFullAccess`, `AmazonS3FullAccess`, `IAMFullAccess`, and `AmazonVPCFullAccess` (for testing/dev only; restrict in production).
   - Download or copy the **Access Key ID** and **Secret Access Key**.

3. **Configure AWS CLI**
   - Install the AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   - Run:
     ```sh
     aws configure
     ```
   - Enter your **Access Key ID**, **Secret Access Key**, default region (`sa-east-1`), and output format (`json`).

---

## Features
- RESTful API for managing TODOs
- Built with Node.js, Express, and TypeORM
- PostgreSQL as the database
- Docker Compose for local development
- Production-ready infrastructure on AWS (provisioned with Terraform)

---

## Local Development

Before starting the services, copy the example environment file:

```sh
cp .env.example .env
```

You can then run the entire stack locally using Docker Compose:

```sh
docker compose up
```

This will start both the API and a local Postgres instance. The API will be available at `http://localhost:3000`.

---

## Building and Pushing the Docker Image for AWS

Build the image for the correct architecture and push to ECR:

```sh
# Create the ECR repository (only needed once)
aws ecr create-repository --repository-name api_pg_test --region sa-east-1

# Build the image
docker buildx build --platform linux/amd64 -t <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.sa-east-1.amazonaws.com/api_pg_test:latest .

# Authenticate to ECR
aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.sa-east-1.amazonaws.com

# Push the image
docker push <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.sa-east-1.amazonaws.com/api_pg_test:latest
```

---

## AWS Infrastructure (Provisioned with Terraform)

The production environment is fully managed by Terraform and includes:

- **ALB (Application Load Balancer):** Public entrypoint, receives all HTTP traffic.
- **ECS (Fargate):** Runs the API containers in private subnets. Only accessible by the ALB.
- **RDS (PostgreSQL):** Managed database in private subnets. Only accessible by ECS tasks (not public).
- **NAT Gateway:** Allows ECS tasks to access the internet (e.g., to pull images from ECR).
- **Security Groups:**
  - ALB SG: Allows inbound HTTP (80) from anywhere.
  - ECS SG: Allows inbound 3000 only from ALB SG.
  - RDS SG: Allows inbound 5432 only from ECS SG.

### High-level Architecture

```svg
<svg width="600" height="340" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="580" height="320" rx="20" fill="#f8f8f8" stroke="#bbb"/>
  <rect x="40" y="40" width="520" height="260" rx="12" fill="#e3f2fd" stroke="#90caf9"/>
  <text x="300" y="65" font-size="18" text-anchor="middle" font-family="Arial">VPC (Private Network)</text>

  <!-- ALB -->
  <rect x="80" y="100" width="120" height="50" rx="8" fill="#fffde7" stroke="#fbc02d"/>
  <text x="140" y="130" font-size="14" text-anchor="middle" font-family="Arial">ALB (Public)</text>
  <text x="140" y="145" font-size="10" text-anchor="middle" font-family="Arial">SG: 80 from 0.0.0.0/0</text>

  <!-- ECS -->
  <rect x="250" y="100" width="120" height="50" rx="8" fill="#e8f5e9" stroke="#43a047"/>
  <text x="310" y="130" font-size="14" text-anchor="middle" font-family="Arial">ECS (Fargate)</text>
  <text x="310" y="145" font-size="10" text-anchor="middle" font-family="Arial">SG: 3000 from ALB SG</text>

  <!-- RDS -->
  <rect x="420" y="100" width="120" height="50" rx="8" fill="#e3eafc" stroke="#3949ab"/>
  <text x="480" y="130" font-size="14" text-anchor="middle" font-family="Arial">RDS (Postgres)</text>
  <text x="480" y="145" font-size="10" text-anchor="middle" font-family="Arial">SG: 5432 from ECS SG</text>

  <!-- NAT Gateway -->
  <rect x="250" y="200" width="120" height="40" rx="8" fill="#fff3e0" stroke="#fb8c00"/>
  <text x="310" y="225" font-size="13" text-anchor="middle" font-family="Arial">NAT Gateway</text>

  <!-- Arrows -->
  <line x1="200" y1="125" x2="250" y2="125" stroke="#888" stroke-width="2" marker-end="url(#arrow)"/>
  <line x1="370" y1="125" x2="420" y2="125" stroke="#888" stroke-width="2" marker-end="url(#arrow)"/>
  <line x1="310" y1="150" x2="310" y2="200" stroke="#888" stroke-width="2" marker-end="url(#arrow)"/>
  <line x1="140" y1="100" x2="140" y2="40" stroke="#888" stroke-width="2" marker-end="url(#arrow)"/>
  <line x1="480" y1="100" x2="480" y2="40" stroke="#888" stroke-width="2" marker-end="url(#arrow)"/>

  <!-- Arrowhead definition -->
  <defs>
    <marker id="arrow" markerWidth="10" markerHeight="10" refX="10" refY="5" orient="auto" markerUnits="strokeWidth">
      <path d="M0,0 L10,5 L0,10" fill="#888" />
    </marker>
  </defs>

  <!-- Labels -->
  <text x="140" y="90" font-size="11" text-anchor="middle" font-family="Arial">HTTP:80</text>
  <text x="310" y="90" font-size="11" text-anchor="middle" font-family="Arial">3000</text>
  <text x="480" y="90" font-size="11" text-anchor="middle" font-family="Arial">5432</text>
  <text x="330" y="190" font-size="10" text-anchor="start" font-family="Arial">ECS outbound to internet</text>
</svg>
```

---

## Security
- **RDS is not accessible from the internet.**
- **ECS tasks are not accessible directly from the internet, only via the ALB.**
- **Only the ALB is public.**

---

## Terraform variables configuration

Before running Terraform, create a file named `terraform.tfvars` at the root of the project with the following content (example values):

```hcl
db_password = "passwordmorethan8chars"
api_image   = "<YOUR_AWS_ACCOUNT_ID>.dkr.ecr.sa-east-1.amazonaws.com/api_pg_test:latest"
```

You can change these values as needed for your environment.

---

## Terraform Commands

```sh
terraform init
terraform plan -out=api-plan.tfplan
terraform apply api-plan.tfplan
```

---

## License
MIT 