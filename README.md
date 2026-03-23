# AWS Infrastructure with Terraform

A production-ready, modular AWS infrastructure built with Terraform. This project provisions a complete 3-tier application architecture — networking, compute, and database — deployed across two Availability Zones in the `eu-north-1` (Stockholm) region.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Infrastructure Components](#infrastructure-components)
  - [Networking (VPC Module)](#networking-vpc-module)
  - [Compute (EC2 Module)](#compute-ec2-module)
  - [Database (RDS Module)](#database-rds-module)
  - [Security Groups](#security-groups)
  - [Remote State Backend](#remote-state-backend)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Configuration Variables](#configuration-variables)
- [Outputs](#outputs)
- [Security Considerations](#security-considerations)
- [Cost Estimation](#cost-estimation)

---

## Architecture Overview

```
                          Internet
                             │
                    ┌────────▼────────┐
                    │  Internet       │
                    │  Gateway        │
                    └────────┬────────┘
                             │
              ┌──────────────▼──────────────┐
              │           VPC               │
              │       10.0.0.0/16           │
              │                             │
              │  ┌──────────┐ ┌──────────┐  │
              │  │  Public  │ │  Public  │  │  ← ALB lives here
              │  │  Subnet  │ │  Subnet  │  │
              │  │eu-north  │ │eu-north  │  │
              │  │  -1a     │ │  -1b     │  │
              │  │10.0.1.0  │ │10.0.2.0  │  │
              │  └────┬─────┘ └─────┬────┘  │
              │       │   ALB       │       │
              │       └──────┬──────┘       │
              │              │              │
              │  ┌───────────▼───────────┐  │
              │  │  Application Load     │  │
              │  │  Balancer (HTTP :80)  │  │
              │  └───────────┬───────────┘  │
              │              │              │
              │  ┌──────────┐│┌──────────┐  │
              │  │ Private  │││ Private  │  │  ← EC2 ASG lives here
              │  │   App    │││   App    │  │
              │  │ Subnet   │││ Subnet   │  │
              │  │eu-north  │││eu-north  │  │
              │  │  -1a     │││  -1b     │  │
              │  │10.0.11.0 │││10.0.12.0 │  │
              │  └────┬─────┘│└─────┬────┘  │
              │  ┌────┴──────┴──────┴────┐  │
              │  │  Auto Scaling Group   │  │
              │  │  EC2: t3.micro × 2    │  │
              │  └────────────┬──────────┘  │
              │               │             │
              │  NAT GW ──────┘             │
              │  (private subnet egress)    │
              │                             │
              │  ┌──────────┐ ┌──────────┐  │
              │  │ Private  │ │ Private  │  │  ← RDS lives here
              │  │   DB     │ │   DB     │  │
              │  │ Subnet   │ │ Subnet   │  │
              │  │eu-north  │ │eu-north  │  │
              │  │  -1a     │ │  -1b     │  │
              │  │10.0.21.0 │ │10.0.22.0 │  │
              │  └──────────┘ └──────────┘  │
              │  ┌──────────────────────┐   │
              │  │  RDS PostgreSQL 16.3 │   │
              │  │  db.t3.micro / 20GB  │   │
              │  └──────────────────────┘   │
              └─────────────────────────────┘
```

**Traffic flow:**
1. Users access the application via the ALB DNS name over HTTP (port 80)
2. The ALB distributes traffic to EC2 instances in private app subnets
3. EC2 instances communicate with RDS PostgreSQL over port 5432
4. Private instances reach the internet (for updates/packages) through the NAT Gateway

---

## Project Structure

```
aws-infrastructure-terraform/
├── backend.tf                     # S3 remote state + DynamoDB locking
├── providers.tf                   # AWS & Random provider configuration
├── variables.tf                   # Root-level input variables
├── outputs.tf                     # Root-level outputs (VPC ID, ALB DNS, DB endpoint)
├── main.tf                        # Module orchestration + security groups
└── modules/
    ├── vpc/                       # Networking layer
    │   ├── main.tf                # VPC, subnets, IGW, NAT, route tables
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ec2/                       # Compute layer
    │   ├── main.tf                # ALB, target group, launch template, ASG
    │   ├── variables.tf
    │   └── outputs.tf
    └── rds/                       # Database layer
        ├── main.tf                # RDS instance, Secrets Manager, subnet group
        ├── variables.tf
        └── outputs.tf
```

---

## Infrastructure Components

### Networking (VPC Module)

The VPC module creates the complete networking foundation for the application.

| Resource | Details |
|---|---|
| VPC | CIDR `10.0.0.0/16`, DNS hostnames & resolution enabled |
| Internet Gateway | Attached to VPC for public subnet internet access |
| Public Subnets | `10.0.1.0/24` (eu-north-1a), `10.0.2.0/24` (eu-north-1b) |
| Private App Subnets | `10.0.11.0/24` (eu-north-1a), `10.0.12.0/24` (eu-north-1b) |
| Private DB Subnets | `10.0.21.0/24` (eu-north-1a), `10.0.22.0/24` (eu-north-1b) |
| NAT Gateway | Deployed in the first public subnet with an Elastic IP |
| Public Route Table | Routes `0.0.0.0/0` → Internet Gateway |
| Private Route Table | Routes `0.0.0.0/0` → NAT Gateway |

**Subnet associations:**
- Public subnets → Public route table (internet-accessible)
- Private app subnets → Private route table (NAT egress only)
- Private DB subnets → Private route table (NAT egress only)

---

### Compute (EC2 Module)

The EC2 module provisions a highly available, auto-scaling compute layer behind a load balancer.

#### Application Load Balancer (ALB)

| Setting | Value |
|---|---|
| Type | Application (Layer 7) |
| Scheme | Internet-facing |
| Subnets | Both public subnets |
| Listener | HTTP port 80 → forward to target group |
| Health check path | `/` |
| Health check interval | 30 seconds |
| Healthy threshold | 2 checks |
| Unhealthy threshold | 3 checks |

#### Auto Scaling Group (ASG)

| Setting | Value |
|---|---|
| AMI | Latest Amazon Linux 2023 (`al2023-ami-*-x86_64`) |
| Instance type | `t3.micro` (configurable) |
| Desired capacity | 2 instances |
| Minimum size | 1 instance |
| Maximum size | 3 instances |
| Subnet placement | Both private app subnets |

The launch template is versioned and uses the most recent Amazon Linux 2023 AMI at the time of deployment.

---

### Database (RDS Module)

The RDS module provisions a managed PostgreSQL database in isolated private subnets with credentials stored securely in AWS Secrets Manager.

| Setting | Value |
|---|---|
| Engine | PostgreSQL |
| Engine version | 16.3 |
| Instance class | `db.t3.micro` |
| Allocated storage | 20 GB |
| Database name | `appdb` |
| Master username | `dbadmin` |
| Multi-AZ | Disabled |
| Skip final snapshot | `true` (dev/test setup) |
| Subnet group | Both private DB subnets |

#### Password Management

The master password is **auto-generated** using the `random_password` resource (16 characters, alphanumeric) and is **never stored in Terraform state in plaintext** — it is written directly to AWS Secrets Manager under the secret name `{project_name}-db-password`.

To retrieve the database password at any time:
```bash
aws secretsmanager get-secret-value \
  --secret-id terraform-db-password \
  --region eu-north-1 \
  --query SecretString \
  --output text
```

---

### Security Groups

Three security groups implement a strict layered (defence-in-depth) access model:

```
Internet → ALB SG → EC2 SG → RDS SG
```

| Security Group | Inbound | Outbound |
|---|---|---|
| **ALB SG** | HTTP (80) from `0.0.0.0/0`, HTTPS (443) from `0.0.0.0/0` | All traffic |
| **EC2 SG** | HTTP (80) from ALB SG only | All traffic |
| **RDS SG** | PostgreSQL (5432) from EC2 SG only | All traffic |

Key principle: EC2 instances are **not** directly reachable from the internet. RDS is **not** reachable from EC2 directly unless via the EC2 security group — there is no public access to the database.

---

### Remote State Backend

Terraform state is stored remotely in S3 with state locking via DynamoDB to prevent concurrent modification.

| Setting | Value |
|---|---|
| S3 bucket | `terraform-state-denis-2026` |
| State key | `prod/terraform.tfstate` |
| Region | `eu-north-1` |
| Encryption | Server-side encryption enabled |
| Lock table | `terraform-lock` (DynamoDB) |

> **Note:** The S3 bucket and DynamoDB table must be created **before** running `terraform init`. They are not managed by this Terraform configuration.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) v2
- An AWS account with sufficient IAM permissions
- The S3 bucket `terraform-state-denis-2026` and DynamoDB table `terraform-lock` must already exist in `eu-north-1`

### Required IAM Permissions

The AWS identity running Terraform needs permissions for:
- `ec2:*` — VPC, subnets, security groups, ALB, ASG, launch templates
- `rds:*` — RDS instances and subnet groups
- `secretsmanager:*` — creating and managing secrets
- `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` — remote state
- `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:DeleteItem` — state locking

---

## Getting Started

### 1. Configure AWS Credentials

```bash
aws configure
# or
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-north-1"
```

### 2. Clone the Repository

```bash
git clone <repository-url>
cd aws-infrastructure-terraform
```

### 3. Initialize Terraform

```bash
terraform init
```

This downloads the required providers (`aws ~> 5.0`, `random ~> 3.0`) and configures the S3 backend.

### 4. Preview the Plan

```bash
terraform plan
```

Review the output carefully. You should see approximately **25–30 resources** to be created.

### 5. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted. The full deployment typically takes **5–10 minutes**, with RDS provisioning being the longest step.

### 6. Access Your Application

After a successful apply, Terraform will output the ALB DNS name:

```
Outputs:

alb_dns_name = "terraform-alb-xxxxxxxxxx.eu-north-1.elb.amazonaws.com"
db_endpoint  = "terraform-db.xxxxxxxxxx.eu-north-1.rds.amazonaws.com:5432"
vpc_id       = "vpc-xxxxxxxxxxxxxxxxx"
```

Open the `alb_dns_name` in your browser to reach the application.

### 7. Destroy the Infrastructure

```bash
terraform destroy
```

> **Warning:** This will permanently delete all provisioned resources including the RDS instance and any data stored in it.

---

## Configuration Variables

### Root Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `project_name` | `string` | `"terraform"` | Prefix applied to all resource names |

### VPC Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | CIDR block for the VPC |
| `public_subnet_cidrs` | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` | CIDR blocks for public subnets |
| `private_app_subnet_cidrs` | `list(string)` | `["10.0.11.0/24", "10.0.12.0/24"]` | CIDR blocks for private app subnets |
| `private_db_subnet_cidrs` | `list(string)` | `["10.0.21.0/24", "10.0.22.0/24"]` | CIDR blocks for private DB subnets |
| `availability_zones` | `list(string)` | `["eu-north-1a", "eu-north-1b"]` | AZs to deploy subnets into |

### EC2 Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `instance_type` | `string` | `"t3.micro"` | EC2 instance type |
| `desired_capacity` | `number` | `2` | Desired number of EC2 instances in the ASG |
| `min_size` | `number` | `1` | Minimum number of instances in the ASG |
| `max_size` | `number` | `3` | Maximum number of instances in the ASG |

### RDS Module Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `db_name` | `string` | `"appdb"` | Name of the database to create |
| `db_username` | `string` | `"dbadmin"` | Master database username |
| `instance_class` | `string` | `"db.t3.micro"` | RDS instance class |
| `allocated_storage` | `number` | `20` | Allocated storage in GB |
| `engine_version` | `string` | `"16.3"` | PostgreSQL engine version |

---

## Outputs

| Output | Description |
|---|---|
| `vpc_id` | The ID of the provisioned VPC |
| `alb_dns_name` | The DNS name of the Application Load Balancer — use this to access the application |
| `db_endpoint` | The connection endpoint of the RDS PostgreSQL instance |

---

## Security Considerations

| Area | Implementation |
|---|---|
| **Database password** | Auto-generated, stored only in AWS Secrets Manager — never in `.tfstate` or source code |
| **Network isolation** | EC2 and RDS are in private subnets with no direct internet access |
| **Principle of least privilege** | Security groups allow only the minimum required traffic between layers |
| **State security** | Remote state is encrypted at rest in S3 with DynamoDB locking to prevent race conditions |
| **No SSH exposure** | Launch template does not configure a key pair — instances are not directly SSH-accessible |

### Recommended Improvements for Production

- Enable **Multi-AZ** on the RDS instance for high availability and automatic failover
- Set `skip_final_snapshot = false` on the RDS instance to retain a snapshot before deletion
- Enable **RDS automated backups** with a retention window of 7+ days
- Add an **HTTPS listener** on the ALB with an ACM certificate and redirect HTTP → HTTPS
- Enable **VPC Flow Logs** for network traffic auditing
- Enable **deletion protection** on the RDS instance
- Consider adding **SSM Session Manager** for secure EC2 shell access without SSH

---

## Cost Estimation

Approximate monthly cost in `eu-north-1` at On-Demand pricing (as of 2026):

| Resource | Quantity | Estimated Cost |
|---|---|---|
| EC2 `t3.micro` | 2 instances | ~$15/mo |
| NAT Gateway | 1 | ~$35/mo |
| ALB | 1 | ~$18/mo |
| RDS `db.t3.micro` | 1 | ~$15/mo |
| S3 (state storage) | minimal | < $1/mo |
| Secrets Manager | 1 secret | ~$0.40/mo |
| **Total** | | **~$85/mo** |

> Costs vary based on traffic volume and data transfer. Use the [AWS Pricing Calculator](https://calculator.aws) for a precise estimate.

---

## Tech Stack

- **Terraform** >= 1.0
- **AWS Provider** ~> 5.0
- **Random Provider** ~> 3.0
- **Region:** eu-north-1 (Stockholm)
