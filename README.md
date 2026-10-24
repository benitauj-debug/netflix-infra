# netflix-infra
**Built by Benita Ujunwa Oswald

![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-us--east--1-7B42BC?logo=amazonwebservices&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-OIDC-7B42BC?logo=githubactions&logoColor=white)
![k3s](https://img.shields.io/badge/k3s-Kubernetes-7B42BC?logo=kubernetes&logoColor=white)
![Argo CD](https://img.shields.io/badge/Argo_CD-GitOps-7B42BC?logo=argo&logoColor=white)

This is the infrastructure for my Netflix movie app. **Terraform** builds everything in AWS, **GitHub Actions** builds the container images and signs in to AWS with **OIDC** (no stored keys), **k3s** runs the app on EC2, and **Argo CD** deploys it from Git.

I wrote this README for two readers: anyone who wants to understand how the project works, and future me, when I come back to it and need the exact commands again.

> **No secrets in this repo.** Account IDs, IP addresses, repo IDs and connection strings appear only as placeholders such as `<ACCOUNT_ID>`. Real values live in `terraform.tfvars` (ignored by Git), in GitHub repository variables and secrets, or in Kubernetes Secrets created by hand.

---

## About this project

I am moving into Cloud and DevOps engineering from a background in virtual executive assistance and digital marketing, through the cloud cohort at **Digital Witch Support Community**. This project started as a cohort assignment and grew into my main hands-on learning project.

### How it grew

| Stage | How the app was deployed |
| --- | --- |
| Version 1 | Frontend and backend cloned into my own GitHub repos. GitHub Actions pushed images to ECR through OIDC. The plan was Docker and Portainer on one EC2 instance, with MongoDB Atlas as the database. Most of the AWS resources were created by hand in the console. |
| Version 2 (this repo) | The cohort asked us to deploy with Terraform and Kubernetes. Instead of starting over, I kept what I had built, **imported** the existing IAM resources into Terraform, and chose k3s on EC2 to keep costs low. |
| Version 3 (in progress) | Added Argo CD, so deployments happen through Git (GitOps) and GitHub never touches the cluster directly. |

### What I wanted to prove to myself

- That I can take infrastructure built by hand and bring it under code without breaking it.
- That I can give CI pipelines access to AWS without a single stored access key.
- That I understand *why* each security setting exists, not just how to copy it.
- That I can troubleshoot calmly by reading errors, instead of guessing.

I share the journey on LinkedIn under **#BenitsCloudJourney**, including the mistakes. You will find the real ones in [Lessons learned](#19-lessons-learned) and [Troubleshooting](#17-troubleshooting).

---

## Table of contents

1. [Project status](#1-project-status)
2. [Architecture](#2-architecture)
3. [Repositories](#3-repositories)
4. [Repository structure](#4-repository-structure)
5. [Prerequisites and local setup](#5-prerequisites-and-local-setup)
6. [Daily routine](#6-daily-routine)
7. [Phase 1: Project setup](#7-phase-1-project-setup)
8. [Phase 2: Bootstrap the state bucket](#8-phase-2-bootstrap-the-state-bucket)
9. [Phase 3: Main config and ECR](#9-phase-3-main-config-and-ecr)
10. [Phase 4: GitHub OIDC and IAM roles](#10-phase-4-github-oidc-and-iam-roles)
11. [Phase 5: Network](#11-phase-5-network)
12. [Phase 6: The k3s node](#12-phase-6-the-k3s-node)
13. [Phase 7: kubectl access](#13-phase-7-kubectl-access)
14. [Phase 8: Kubernetes manifests](#14-phase-8-kubernetes-manifests)
15. [Phase 9: GitOps with Argo CD](#15-phase-9-gitops-with-argo-cd)
16. [Cost control and teardown](#16-cost-control-and-teardown)
17. [Troubleshooting](#17-troubleshooting)
18. [Security decisions](#18-security-decisions)
19. [Lessons learned](#19-lessons-learned)
20. [Future improvements](#20-future-improvements)
21. [References](#21-references)
22. [About me](#about-me)

---

## 1. Project status

| Phase | What it builds | Status |
| --- | --- | --- |
| 1 | Repo, folder structure, `.gitignore` | Done |
| 2 | S3 bucket for Terraform state | Done |
| 3 | Terraform backend, providers, ECR repositories | Done |
| 4 | GitHub OIDC provider and both IAM roles imported into Terraform | Done |
| 5 | VPC, public subnet, internet gateway, security group | Planned |
| 6 | EC2 node with k3s installed at boot | Planned |
| 7 | kubectl access from WSL | Planned |
| 8 | Kubernetes manifests for frontend, backend and ingress | Planned |
| 9 | Argo CD and GitOps deploy pipeline | Planned |

Both app pipelines already push images to the ECR repositories created by Terraform.

---

## 2. Architecture

### Target architecture
<img width="4716" height="2740" alt="image" src="https://github.com/user-attachments/assets/b6c4bd00-7ae8-4acd-aa2a-98f0ed2edd93" />




 It has numbered, colour coded, animated flows, a "How it works" panel, and hover notes on every box. and choose **File > Open from > Device**, or install the **Draw.io Integration** extension in VS Code and open the file inside the repo. After editing, export a picture with **File > Export as > PNG** to `docs/architecture.png` and commit both files.

The diagram below is the same architecture in Mermaid, which GitHub renders directly on this page.

### How a request flows

1. A visitor opens `http://<ELASTIC_IP>` on port 80, the only port open to the public.
2. Traefik (the ingress controller bundled with k3s) routes `/api` to the backend Service and everything else to the frontend Service.
3. The backend reads movie data from MongoDB Atlas, which only accepts connections from the node's Elastic IP.

### How a deploy flows (GitOps)

1. A developer pushes code to `movie-frontend` or `movie-backend`.
2. GitHub Actions requests a short lived AWS token through OIDC, builds the image, tags it with the commit SHA, and pushes it to ECR.
3. The same workflow updates the image tag in `netflix-infra/k8s/kustomization.yaml` and commits it.
4. Argo CD, running inside the cluster, sees the commit and applies it.
5. Kubernetes rolls out new pods, which pull the image from ECR.

### Responsibility boundaries

| Tool | Owns |
| --- | --- |
| Terraform | Everything in AWS: state bucket, ECR, IAM, network, EC2 |
| GitHub Actions | Building and pushing images, updating the image tag in Git |
| Argo CD | Everything inside the Kubernetes cluster |
| Git (`netflix-infra`) | The single source of truth for infrastructure and cluster state |

---

## 3. Repositories

| Repository | Purpose |
| --- | --- |
| `benitauj-debug/movie-frontend` | React frontend, its Dockerfile and CI workflow |
| `benitauj-debug/movie-backend` | Java 17 (Maven) backend, its Dockerfile and CI workflow |
| `benitauj-debug/netflix-infra` | This repo: Terraform, Kubernetes manifests, Argo CD config |

App code and infrastructure live in separate repos because they change for different reasons, need different permissions, and run through different pipelines.

---

## 4. Repository structure

```text
netflix-infra/
├── bootstrap/
│   ├── main.tf                  # Creates the S3 state bucket (local state, run once)
│   └── .terraform.lock.hcl
├── terraform/
│   ├── backend.tf               # Remote state in S3 with locking
│   ├── providers.tf             # Terraform and AWS provider versions, default tags
│   ├── variables.tf             # Input variables
│   ├── terraform.tfvars         # Real values (git ignored, never committed)
│   ├── terraform.tfvars.example # Safe template of the above (committed)
│   ├── ecr.tf                   # ECR repositories and lifecycle policies
│   ├── iam_github.tf            # OIDC provider, backend role and its policy (imported)
│   ├── iam_github_frontend.tf   # Frontend role and its policy (imported)
│   ├── network.tf               # VPC, subnet, routing, security group
│   ├── k3s_node.tf              # EC2 node, instance role, Elastic IP
│   ├── outputs.tf               # Values printed after apply
│   ├── templates/
│   │   └── k3s-userdata.sh.tftpl
│   └── .terraform.lock.hcl
├── k8s/
│   ├── kustomization.yaml       # Lists manifests and pins image tags
│   ├── backend.yaml
│   ├── frontend.yaml
│   └── ingress.yaml
├── argocd/
│   └── netflix-app.yaml         # Argo CD Application
├── docs/
│   └── architecture.drawio      # Editable architecture diagram (draw.io)
├── scripts/
├── .gitignore
└── README.md
```

---

## 5. Prerequisites and local setup

All commands run inside **Ubuntu on WSL2**, never in PowerShell or Git Bash. Check the prompt first:

| Prompt | Environment | Use it for |
| --- | --- | --- |
| `benita@DESKTOP-...:~$` | Ubuntu (Linux) | Everything in this README |
| `PS C:\>` | PowerShell | Only `wsl` commands to start or fix Ubuntu |
| `MINGW64` | Git Bash | Nothing here |

Keep the project in the Linux home folder (`~/netflix-infra`), not under `/mnt/c`. The Windows disk is slower from Linux and causes permission problems.

### Tools

| Tool | Check | Notes |
| --- | --- | --- |
| Terraform | `terraform version` | 1.10 or newer (needed for S3 native locking and import blocks) |
| AWS CLI v2 | `aws --version` | Uses `aws login` for short lived credentials |
| Git | `git --version` | SSH key added to GitHub |
| kubectl | `kubectl version --client` | Installed in Phase 7 |
| argocd CLI | `argocd version --client` | Installed in Phase 9 |
| VS Code | | With the **HashiCorp Terraform** extension installed in WSL |

### Install Terraform from HashiCorp's official repository

```bash
sudo apt update && sudo apt install -y gnupg software-properties-common wget
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

The GPG key lets apt verify that every package really came from HashiCorp. `$(lsb_release -cs)` inserts the Ubuntu codename (for example `noble`) so apt picks the right package set.

### Share one provider download across projects

The AWS provider is a large download. This makes Terraform keep one shared copy instead of downloading it per folder:

```bash
mkdir -p ~/.terraform.d/plugin-cache
echo 'plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"' > ~/.terraformrc
```

### Stop the AWS CLI opening a pager

```bash
echo 'export AWS_PAGER=""' >> ~/.bashrc
source ~/.bashrc
```

Use `>>` (append). A single `>` would overwrite `.bashrc`.

### GitHub SSH access from Ubuntu

```bash
ssh-keygen -t ed25519 -C "<YOUR_GITHUB_EMAIL>" -f ~/.ssh/github
code ~/.ssh/config
```

Add to `~/.ssh/config`:

```text
Host github.com
  IdentityFile ~/.ssh/github
  IdentitiesOnly yes
```

```bash
chmod 600 ~/.ssh/config
cat ~/.ssh/github.pub          # paste into GitHub: Settings > SSH and GPG keys
ssh -T git@github.com          # expect: "Hi <username>! You've successfully authenticated"
```

Only the `.pub` file is ever shared. `ssh -T` always exits with code 1 because GitHub does not provide a shell; the greeting message is what matters.

---

## 6. Daily routine

### Start of a session

```bash
cd ~/netflix-infra
aws login --remote                 # WSL cannot open a browser; open the printed link in Chrome
aws sts get-caller-identity        # Arn must end in user/<YOUR_IAM_USER>, never root
git pull
cd terraform
terraform plan                     # expect "No changes" if nothing was changed since last time
```

`aws login` issues temporary credentials. They refresh automatically, but the session ends after the duration set on the IAM identity (at most 12 hours). When any command says `ExpiredToken`, log in again.

If old exported credentials are lingering in the terminal, clear them first:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION
```

### End of a session

```bash
cd ~/netflix-infra
git status          # read it: no .tfstate, .tfvars, .tfplan or kubeconfig must appear
git add .
git commit -m "Describe what you finished"
git push
```

From Phase 6 onward, also run `terraform destroy` (see [Cost control](#16-cost-control-and-teardown)).

### Safe Terraform workflow

Always save the plan and apply exactly what you reviewed:

```bash
terraform fmt
terraform validate
terraform plan -out=change.tfplan
# read the whole plan
terraform apply change.tfplan
```

Applying a saved plan does not ask for `yes`, because saving it was the approval. Plan files can contain real values, so `*.tfplan` is git ignored.

---

## 7. Phase 1: Project setup

```bash
mkdir -p ~/netflix-infra/{bootstrap,terraform,k8s,argocd,scripts}
cd ~/netflix-infra
git init
git branch -M main          # Argo CD watches the main branch
touch bootstrap/.gitkeep k8s/.gitkeep scripts/.gitkeep    # Git does not track empty folders
code .
```

### .gitignore

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfplan
crash.log

# Kubernetes credentials
kubeconfig*
k3s.yaml
*-k3s.yaml

# Keys and secrets
*.pem
*.key
.env
```

`.terraform.lock.hcl` is deliberately **not** ignored. It records the exact provider versions so every machine uses the same ones. `*.yaml` is deliberately **not** ignored, because the Kubernetes manifests must be committed.

Test it:

```bash
git check-ignore -v bootstrap/terraform.tfstate   # ignored by line 2
git check-ignore -v terraform/terraform.tfvars    # ignored by line 4
git check-ignore -v k8s/backend.yaml              # prints nothing: tracked, as it should be
```

### Push to GitHub

Create an empty repo on GitHub (no README, `.gitignore` or license, or the first push is rejected), then:

```bash
git remote add origin git@github.com:benitauj-debug/netflix-infra.git
git remote -v
git add .
git status
git commit -m "Initial project structure"
git push -u origin main
```

---

## 8. Phase 2: Bootstrap the state bucket

Terraform state is Terraform's record of what it manages. It belongs in a remote, versioned, encrypted, locked location, never only on a laptop.

The state bucket is itself infrastructure, so a tiny separate **bootstrap** config creates it, keeps its own state locally, and runs once.

### bootstrap/main.tf

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "<STATE_BUCKET_NAME>"   # globally unique across all AWS accounts

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}
```

| Setting | Why |
| --- | --- |
| `prevent_destroy` | Terraform refuses to delete the bucket. Losing state means Terraform forgets everything it manages. |
| Versioning | A corrupted state file can be rolled back. |
| Encryption | State can hold sensitive values. |
| Public access block | State must never be readable by the world. |

### Run

```bash
cd ~/netflix-infra/bootstrap
terraform init
terraform validate
terraform plan -out=bootstrap.tfplan      # expect: 4 to add
terraform apply bootstrap.tfplan
```

Terraform creates the bucket first, then the other three resources **in parallel**, because each one references `aws_s3_bucket.tf_state.id`. References alone define the dependency graph.

### Verify with AWS directly

```bash
aws s3api get-bucket-versioning     --bucket <STATE_BUCKET_NAME>   # "Status": "Enabled"
aws s3api get-public-access-block   --bucket <STATE_BUCKET_NAME>   # four true values
aws s3api get-bucket-encryption     --bucket <STATE_BUCKET_NAME>   # "SSEAlgorithm": "AES256"
```

---

## 9. Phase 3: Main config and ECR

All files below live in `terraform/`.

### backend.tf

```hcl
terraform {
  backend "s3" {
    bucket       = "<STATE_BUCKET_NAME>"
    key          = "netflix/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

A backend block cannot use variables, so the bucket name is written directly. `use_lockfile = true` stores a lock file next to the state in S3, so two runs can never write state at the same time. Terraform 1.10 and later lock natively in S3, so no DynamoDB table is needed.

### providers.tf

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = "netflix"
      ManagedBy = "terraform"
      Owner     = "benita"
    }
  }
}
```

`default_tags` labels every resource, which makes cost reports and cleanup easy, and tells anyone in the console not to edit it by hand.

### variables.tf

```hcl
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "my_ip_cidr" {
  type        = string
  description = "Public IP as x.x.x.x/32, the only address allowed to reach SSH and the Kubernetes API"
}

variable "ecr_repo_names" {
  type        = list(string)
  description = "Must match the ECR_REPOSITORY variable in each app repo"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/netflix-k3s.pub"
}
```

### terraform.tfvars.example (committed)

```hcl
# Copy to terraform.tfvars and fill in real values. terraform.tfvars is git ignored.
my_ip_cidr     = "<YOUR_PUBLIC_IP>/32"   # curl -s https://checkip.amazonaws.com
ecr_repo_names = ["frontend-repo", "backend-repo"]
```

The ECR names are not hard coded in the app workflows. Each workflow reads `${{ vars.ECR_REPOSITORY }}`, a GitHub **repository variable** (Settings > Secrets and variables > Actions > Variables). Terraform must use exactly those names.

A home IP can change when the router restarts. When SSH or kubectl suddenly time out, check this value first.

### ecr.tf

```hcl
resource "aws_ecr_repository" "app" {
  for_each             = toset(var.ecr_repo_names)
  name                 = each.key
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
```

| Setting | Why |
| --- | --- |
| `for_each` | One block creates a repo per name. Adding a repo is a one line change. |
| `MUTABLE` | The workflows push both a commit SHA tag and `latest`. Switch to `IMMUTABLE` once `latest` is removed. |
| `force_delete` | Lets `destroy` remove repos that still hold images. Fine for learning, off in production. |
| `scan_on_push` | Every image is scanned for known vulnerabilities. |
| Lifecycle policy | Old images expire automatically, so storage cost stays flat. |

### Run

```bash
cd ~/netflix-infra/terraform
terraform init           # "Successfully configured the backend s3!"
terraform validate
terraform plan -out=main.tfplan     # 4 to add: 2 repos, 2 lifecycle policies
terraform apply main.tfplan
aws ecr describe-repositories --query "repositories[].repositoryName"
aws s3 ls s3://<STATE_BUCKET_NAME>/netflix/       # terraform.tfstate is now in S3
```

---

## 10. Phase 4: GitHub OIDC and IAM roles

### Why OIDC

GitHub Actions needs AWS permissions to push images. The old way stores long lived access keys as GitHub secrets, which work until someone deletes them and are a common source of leaks.

With OIDC, GitHub issues a signed, short lived token for each workflow run. AWS checks the token against a trust policy and returns temporary credentials. **No AWS keys are stored anywhere.**

```text
Workflow run  ->  GitHub OIDC token  ->  AWS STS AssumeRoleWithWebIdentity
              ->  trust policy checks aud and sub  ->  temporary credentials  ->  push to ECR
```

### Design: one role per pipeline

| Role | Trusted repo | Can push to |
| --- | --- | --- |
| `GitHubActionsECRPush` | `movie-backend`, branch `main` | backend image repo |
| `GithubActionsFrontendECRPush` | `movie-frontend`, branch `main` | frontend image repo |

Separate roles are least privilege: a compromised frontend pipeline cannot overwrite backend images. Both roles share one OIDC provider.

### Importing resources created by hand

These were first created in the console. Importing brings them under Terraform without recreating them.

**Step 1: inspect what exists**

```bash
aws iam list-open-id-connect-providers
aws iam get-role --role-name <ROLE_NAME> --query "Role.AssumeRolePolicyDocument"
aws iam list-attached-role-policies --role-name <ROLE_NAME>   # managed policies
aws iam list-role-policies --role-name <ROLE_NAME>            # inline policies
```

Managed and inline policies are different Terraform resource types, so this decides which import block to write.

**Step 2: temporary `import.tf`**

```hcl
import {
  to = aws_iam_openid_connect_provider.github
  id = "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
}

import {
  to = aws_iam_role.github_actions
  id = "GitHubActionsECRPush"
}

import {
  to = aws_iam_role_policy.github_ecr
  id = "GitHubActionsECRPush:GitHubActionsECRPushPolicy"   # role_name:policy_name
}
```

Each resource type has its own import ID format: a full ARN for the provider, a name for the role, `role:policy` for an inline policy. IDs are case sensitive.

**Step 3: let Terraform write the code**

```bash
terraform plan -generate-config-out=iam_github.tf
```

Config generation is experimental. Read the generated file, and fix anything it gets wrong (see [Troubleshooting](#17-troubleshooting)). If you need to generate again, use a new file name; Terraform will not overwrite an existing file.

**Step 4: plan until only expected changes remain, then apply**

```bash
terraform plan -no-color | grep -E "will be updated|^\s+~|^\s+\+ "
terraform plan -out=import.tfplan
terraform apply import.tfplan
rm import.tf
terraform plan          # must say: No changes
```

During import the only change should be the `default_tags` being added. Any change to a trust policy, permission policy or URL must be understood before applying.

The frontend role was imported the same way into `iam_github_frontend.tf`.

### Resulting code (shape, with placeholders)

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["<THUMBPRINT>"]
}

resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsECRPush"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:<OWNER>@<OWNER_ID>/movie-backend@<REPO_ID>:ref:refs/heads/main"
        }
      }
    }]
  })
}
```

### The two trust conditions

| Condition | Meaning |
| --- | --- |
| `aud` | The token was issued for AWS STS. A second layer of defence; keep it. |
| `sub` | Exactly which repo and branch may assume the role. |

The `sub` value here includes numeric owner and repo IDs (`owner@id/repo@id`). IDs never change even if a repo is renamed or deleted and recreated, so an attacker cannot claim the role by creating a repo with the same name. Copy the exact value from AWS; never retype it.

`StringLike` without a `*` wildcard behaves exactly like `StringEquals`.

### Verify

```bash
aws iam get-role --role-name GitHubActionsECRPush \
  --query "Role.AssumeRolePolicyDocument.Statement[0].Condition"
aws ecr list-images --repository-name backend-repo
aws ecr list-images --repository-name frontend-repo
```

A successful pipeline run is the real proof: the **Configure AWS credentials** step succeeds and images appear in ECR.

---

## 11. Phase 5: Network

### network.tf

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "netflix-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "netflix-public-a" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "netflix-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "netflix-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "k3s" {
  name        = "netflix-k3s-node"
  description = "k3s node: web open, admin restricted"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k3s.id
  cidr_ipv4         = var.my_ip_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from my IP only"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.k3s.id
  cidr_ipv4         = var.my_ip_cidr
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  description       = "Kubernetes API from my IP only"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.k3s.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Public web traffic"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.k3s.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Public web traffic"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.k3s.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound: ECR, Atlas, package updates"
}
```

A subnet is **public** because its route table sends `0.0.0.0/0` to an internet gateway, not because of its name.

```bash
terraform plan -out=network.tfplan     # 11 to add
terraform apply network.tfplan
```

**Production difference:** nodes would sit in private subnets across two or more Availability Zones, behind a load balancer, with a NAT gateway for outbound traffic and no SSH. That costs noticeably more, which is why this project uses one public subnet.

---

## 12. Phase 6: The k3s node

> **Cost starts here.** The EC2 instance and its public IPv4 address bill every hour they exist. Check current prices on the AWS pricing pages.

### SSH key for the node

```bash
ssh-keygen -t ed25519 -f ~/.ssh/netflix-k3s -C "netflix-k3s"
chmod 600 ~/.ssh/netflix-k3s
```

### k3s_node.tf

```hcl
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "k3s_node" {
  name = "netflix-k3s-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k3s_node" {
  name = "netflix-k3s-node"
  role = aws_iam_role.k3s_node.name
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "k3s" {
  key_name   = "netflix-k3s"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_eip" "k3s" {
  domain = "vpc"
  tags   = { Name = "netflix-k3s-ip" }
}

resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  key_name               = aws_key_pair.k3s.key_name
  iam_instance_profile   = aws_iam_instance_profile.k3s_node.name

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/k3s-userdata.sh.tftpl", {
    public_ip  = aws_eip.k3s.public_ip
    region     = var.region
    account_id = data.aws_caller_identity.current.account_id
  })
  user_data_replace_on_change = true

  tags = { Name = "netflix-k3s-node" }
}

resource "aws_eip_association" "k3s" {
  instance_id   = aws_instance.k3s.id
  allocation_id = aws_eip.k3s.id
}
```

| Decision | Why |
| --- | --- |
| Node role: ECR read only + SSM | Least privilege. The node can pull images, nothing more. |
| `http_tokens = "required"` | Forces IMDSv2, which blocks a common credential theft technique. |
| `hop_limit = 1` | Pods sit one hop further than the host, so they cannot reach the metadata service or borrow the node's role. |
| Elastic IP allocated first | The boot script needs the final IP for the Kubernetes API certificate. |
| `user_data_replace_on_change` | User data only runs on first boot, so changing it rebuilds the instance. |
| `pathexpand` | `file()` does not understand `~`. |
| `t3.medium` | k3s plus the app plus Argo CD needs more than 1 GB of RAM. |

### templates/k3s-userdata.sh.tftpl

```bash
#!/bin/bash
set -euo pipefail
exec > /var/log/k3s-bootstrap.log 2>&1

apt-get update -y
apt-get install -y unzip curl

# AWS CLI v2, used to refresh the ECR pull secret
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# k3s, with the Elastic IP added to the API certificate
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --tls-san ${public_ip} --write-kubeconfig-mode 600" sh -

until k3s kubectl get nodes > /dev/null 2>&1; do sleep 5; done

k3s kubectl create namespace netflix --dry-run=client -o yaml | k3s kubectl apply -f -

# ECR tokens expire after 12 hours, so refresh the pull secret every 6 hours
cat > /usr/local/bin/refresh-ecr-secret.sh <<'EOF'
#!/bin/bash
set -euo pipefail
TOKEN=$(/usr/local/bin/aws ecr get-login-password --region ${region})
k3s kubectl -n netflix create secret docker-registry ecr-creds \
  --docker-server=${account_id}.dkr.ecr.${region}.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$TOKEN" \
  --dry-run=client -o yaml | k3s kubectl apply -f -
EOF
chmod 700 /usr/local/bin/refresh-ecr-secret.sh
/usr/local/bin/refresh-ecr-secret.sh

echo "0 */6 * * * root /usr/local/bin/refresh-ecr-secret.sh >> /var/log/ecr-refresh.log 2>&1" > /etc/cron.d/ecr-refresh
```

Terraform fills in `${public_ip}`, `${region}` and `${account_id}` before the script reaches the server, so no account ID is stored in Git.

`--dry-run=client -o yaml | kubectl apply -f -` creates an object if missing, or updates it if present.

In production, pin `INSTALL_K3S_VERSION` so every rebuild installs a tested version.

### outputs.tf

```hcl
output "node_public_ip" {
  value = aws_eip.k3s.public_ip
}

output "node_instance_id" {
  value = aws_instance.k3s.id
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/netflix-k3s ubuntu@${aws_eip.k3s.public_ip}"
}

output "ecr_repository_urls" {
  value = { for name, repo in aws_ecr_repository.app : name => repo.repository_url }
}
```

### Run and check the boot

```bash
terraform plan -out=node.tfplan
terraform apply node.tfplan
# wait about 3 minutes
$(terraform output -raw ssh_command)
sudo tail -n 30 /var/log/k3s-bootstrap.log
sudo k3s kubectl get nodes                       # Ready
sudo k3s kubectl -n netflix get secret ecr-creds # exists
```

---

## 13. Phase 7: kubectl access

### Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client
```

### Copy the kubeconfig

```bash
cd ~/netflix-infra/terraform
IP=$(terraform output -raw node_public_ip)
mkdir -p ~/.kube
ssh -i ~/.ssh/netflix-k3s ubuntu@$IP "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/netflix-k3s.yaml
sed -i "s/127.0.0.1/$IP/" ~/.kube/netflix-k3s.yaml
chmod 600 ~/.kube/netflix-k3s.yaml
export KUBECONFIG=~/.kube/netflix-k3s.yaml
kubectl get nodes
```

k3s writes `127.0.0.1` because it only knows itself. `sed` swaps in the Elastic IP. The `--tls-san` flag from Phase 6 makes the certificate valid for that IP.

**The kubeconfig is a root password for the cluster.** It lives in `~/.kube`, outside the repo, and must never be committed or shared.

---

## 14. Phase 8: Kubernetes manifests

### Facts to confirm from the app code

| Fact | Where to look | Expected |
| --- | --- | --- |
| Backend port | Spring Boot `application.properties` (`server.port`) | Usually `8080` |
| Backend env var for the Mongo connection string | Backend config | Placeholder: `<MONGO_ENV_NAME>` |
| Frontend container port | Frontend `Dockerfile` `EXPOSE` | `80` for nginx |
| Frontend API URL | `REACT_APP_API_URL` repository variable in `movie-frontend` | Set to `/api` |

`REACT_APP_API_URL` is baked into the JavaScript at build time, because the frontend runs in the browser. Setting it to `/api` makes the browser call the same address it loaded the page from, and the Ingress routes it to the backend. Re-run the frontend workflow after changing it.

### Allow the node in MongoDB Atlas

Atlas > Network Access: add `<ELASTIC_IP>/32`. Remove any `0.0.0.0/0` entry.

### Database Secret (created by hand, never in Git)

```bash
 kubectl -n netflix create secret generic backend-env \
  --from-literal=<MONGO_ENV_NAME>='<MONGODB_CONNECTION_STRING>'
```

The leading space stops the command, password included, being saved to shell history. A Kubernetes Secret is only base64 encoded, not encrypted; production would use AWS Secrets Manager with External Secrets Operator.

### k8s/backend.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: netflix
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      imagePullSecrets:
        - name: ecr-creds
      containers:
        - name: backend
          image: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/backend-repo:<TAG>
          ports:
            - containerPort: 8080
          envFrom:
            - secretRef:
                name: backend-env
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              memory: 512Mi
          readinessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 20
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 20
          securityContext:
            allowPrivilegeEscalation: false
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: netflix
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 8080
```

Java apps start slower and use more memory than Node apps, hence the longer probe delays and higher memory values. If the backend has a health endpoint (for example Spring Boot Actuator `/actuator/health`), switch the probes to `httpGet`.

### k8s/frontend.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: netflix
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      imagePullSecrets:
        - name: ecr-creds
      containers:
        - name: frontend
          image: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/frontend-repo:<TAG>
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              memory: 128Mi
          readinessProbe:
            tcpSocket:
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: netflix
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
```

### k8s/ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: netflix
  namespace: netflix
spec:
  ingressClassName: traefik
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```

If the backend routes do **not** start with `/api`, add a Traefik `Middleware` with `stripPrefix` and reference it from the Ingress annotation `traefik.ingress.kubernetes.io/router.middlewares: netflix-strip-api@kubernetescrd`.

### k8s/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: netflix
resources:
  - backend.yaml
  - frontend.yaml
  - ingress.yaml
images:
  - name: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/backend-repo
    newTag: <CURRENT_BACKEND_TAG>
  - name: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/frontend-repo
    newTag: <CURRENT_FRONTEND_TAG>
```

Kustomize replaces the tag of every image whose name matches. This gives the pipeline **one place** to change the deployed version.

### First manual deploy (before Argo CD)

```bash
cd ~/netflix-infra
kubectl kustomize k8s          # preview the final YAML
kubectl apply -k k8s
kubectl -n netflix get pods -w
kubectl -n netflix get svc,ingress
curl -I http://$(cd terraform && terraform output -raw node_public_ip)
```

Get the app working by hand first. Adding Argo CD to a broken cluster makes it hard to tell which layer is failing.

---

## 15. Phase 9: GitOps with Argo CD

### Push model vs pull model

| | Push (GitHub deploys into the cluster) | Pull (Argo CD, used here) |
| --- | --- | --- |
| Who changes the cluster | The CI pipeline | Argo CD, from inside the cluster |
| Cluster credentials in CI | Needed | None |
| Kubernetes API exposed to CI | Yes, or a workaround | Never |
| Audit trail | CI logs | Every deploy is a Git commit |
| Rollback | Re-run an old pipeline | `git revert` |
| Manual drift | Stays until noticed | Reverted automatically (self heal) |

### Check node capacity

```bash
kubectl top nodes
```

Argo CD needs roughly 1 GB of memory. If memory is above about 60%, set `instance_type = "t3.large"` and apply. An instance type change stops and starts the same instance, so the Elastic IP and cluster survive.

### Install Argo CD (pinned version)

```bash
ARGOCD_VERSION=<vX.Y.Z>     # pick from github.com/argoproj/argo-cd/releases
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
kubectl -n argocd get pods -w
```

`--server-side` is required because some Argo CD resource definitions are too large for normal `kubectl apply`.

Argo CD is installed by hand, not by Terraform: Terraform builds the platform, Argo CD manages what runs on it. Managing in-cluster objects from the same Terraform run that creates the cluster causes ordering problems.

### CLI, dashboard and password

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

In a second terminal, keep a private tunnel open:

```bash
export KUBECONFIG=~/.kube/netflix-k3s.yaml
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then:

```bash
argocd admin initial-password -n argocd
argocd login localhost:8080 --username admin --insecure
argocd account update-password
kubectl -n argocd delete secret argocd-initial-admin-secret
```

Open `https://localhost:8080` in Chrome. Argo CD is never exposed to the internet: whoever controls it can deploy anything into the cluster. `--insecure` is acceptable only because traffic stays inside the tunnel.

### Repo access with deploy keys

| Key | Repo | Access | Used by |
| --- | --- | --- | --- |
| `argocd-read` | `netflix-infra` | Read only | Argo CD |
| `ci-write` | `netflix-infra` | Read and write | App pipelines (stored as `INFRA_DEPLOY_KEY` secret) |

```bash
ssh-keygen -t ed25519 -f ~/.ssh/argocd-netflix-infra -N "" -C "argocd-read"
# add the .pub to netflix-infra > Settings > Deploy keys, write access OFF
argocd repo add git@github.com:benitauj-debug/netflix-infra.git \
  --ssh-private-key-path ~/.ssh/argocd-netflix-infra
argocd repo list       # STATUS: Successful
```

For a public repo, Argo CD can read over HTTPS without a key; the write key is still needed for CI.

### argocd/netflix-app.yaml

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: netflix
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:benitauj-debug/netflix-infra.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: netflix
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

| Field | Meaning |
| --- | --- |
| `path: k8s` | Argo CD builds `k8s/kustomization.yaml` |
| `automated` | Applies Git changes without a manual sync |
| `prune` | Deletes objects removed from Git. Only touches objects this Application manages, so hand made Secrets are safe. |
| `selfHeal` | Undoes manual changes made directly in the cluster |

```bash
kubectl apply -f argocd/netflix-app.yaml
argocd app get netflix        # Synced, Healthy
```

**Self heal test:**

```bash
kubectl -n netflix scale deployment backend --replicas=5
kubectl -n netflix get pods -w      # Argo CD scales it back to 2, because Git says 2
```

To change replicas for real, change Git.

### Pipeline step that updates Git

Added to both app workflows after the build and push step. The ECR login step must have `id: ecr`.

```yaml
      - name: Check out infra repo
        uses: actions/checkout@v4
        with:
          repository: benitauj-debug/netflix-infra
          ssh-key: ${{ secrets.INFRA_DEPLOY_KEY }}
          path: infra

      - name: Update image tag in Git
        env:
          IMAGE_NAME: ${{ steps.ecr.outputs.registry }}/${{ vars.ECR_REPOSITORY }}
          TAG: ${{ github.sha }}
        run: |
          cd infra
          yq -i '(.images[] | select(.name == strenv(IMAGE_NAME))).newTag = strenv(TAG)' k8s/kustomization.yaml
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add k8s/kustomization.yaml
          git commit -m "deploy(backend): ${TAG}"     # deploy(frontend) in the frontend workflow
          git pull --rebase
          git push
```

`git pull --rebase` handles the case where the other pipeline pushed a moment earlier.

### Rollback, the GitOps way

```bash
cd ~/netflix-infra
git pull
git log --oneline -5
git revert <BAD_DEPLOY_COMMIT_SHA>
git push
```

Do not use `argocd app rollback` with automated sync on: Argo CD refuses it, because Git would win again immediately. In GitOps, you fix Git, never the cluster.

---

## 16. Cost control and teardown

| Resource | Cost |
| --- | --- |
| S3 state bucket, ECR (small), IAM, VPC, subnet, security group | Free or a few cents |
| EC2 instance | Per hour |
| Public IPv4 / Elastic IP | Per hour |

From Phase 6 onward, destroy the node at the end of every session:

```bash
cd ~/netflix-infra/terraform
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

Read the destroy plan. It also removes the imported OIDC provider and roles, which breaks the pipelines until the next `apply`. To destroy only the expensive parts:

```bash
terraform destroy -target=aws_eip_association.k3s -target=aws_instance.k3s -target=aws_eip.k3s
```

`-target` is for exceptional use, not everyday workflow.

The state bucket survives because it lives in `bootstrap/` with `prevent_destroy`.

**After a rebuild**, the Elastic IP is new. Update:

1. The kubeconfig (Phase 7)
2. The MongoDB Atlas allowlist
3. The `ecr-creds` and `backend-env` Secrets (created again on the new node)
4. Argo CD (installed again on the new cluster)

---

## 17. Troubleshooting

Work through the layers before changing anything: what changed, what was expected, what is actually happening, and which layer is failing.

### Local environment

| Symptom | Cause | Fix |
| --- | --- | --- |
| `wsl -l -v` hangs, Ubuntu and Docker Desktop dead | WSL service stuck after an update | Quit Docker Desktop, **Restart** Windows (not Shut down), or `Restart-Service WslService -Force` as admin |
| `wsl: command not found` inside Ubuntu | `wsl` is a Windows program | Run it from PowerShell |
| `cd: too many arguments` | A space inside a path, for example `cd ~ /netflix-infra` | `cd ~/netflix-infra` |
| VS Code shows TypeScript errors (`ts(1005)`) in `.tf` files | Wrong language mode | Install the HashiCorp Terraform extension in WSL, or Change Language Mode to Terraform. Never click Quick Fix. |
| AWS CLI output stuck with `:` at the bottom | Output opened in the `less` pager | Press `q`; set `AWS_PAGER=""` |
| `git commit` opens nano | No `-m` message | `Ctrl+X`, then commit with `-m "message"` |

### Git

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Permission denied (publickey)` | No GitHub key in Ubuntu | Create a key, add to GitHub, configure `~/.ssh/config` |
| `src refspec main does not match any` | Branch is called `master` | `git branch -M main` |
| `rejected ... (fetch first)` | Remote has commits you do not | `git pull --rebase origin main`, then push. Avoid `--force`. |
| `git push` says `Everything up-to-date` but nothing changed on GitHub | Files staged but not committed | `git commit -m "..."`, then push |
| `fatal: not a git repository` | Folder not initialised or wrong folder | `git init`, or check `pwd` |

### Terraform

| Symptom | Cause | Fix |
| --- | --- | --- |
| `init` hangs at `Installing hashicorp/aws` | Slow or interrupted download | `Ctrl+C`, reuse an already downloaded provider, enable the plugin cache |
| `Missing required provider` / inconsistent lock file | `init` never finished | Run `terraform init` on its own and read its first error |
| `ExpiredToken` / `failed to refresh cached credentials` | `aws login` session ended | `aws login --remote` |
| `Error acquiring the state lock` with `ExpiredToken` in it | Credentials, not a real lock | Log in again. Never use `-lock=false`. |
| `flag provided but not defined: -output` | Wrong flag | `-out=file.tfplan` |
| `validate` passes but changes are not checked | Command run in the wrong folder | Check the prompt: Terraform files are in `~/netflix-infra/terraform` |
| `expected "url" to have a host` after import | Generated config wrote the OIDC URL without `https://` | Set `url = "https://token.actions.githubusercontent.com"` |
| Import plan shows `N to change` | Usually `default_tags` being added | Filter the plan; only tags may change |

### GitHub Actions and IAM

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `sub` in the trust policy does not match the token | Copy the exact `sub` from AWS, check repo name, branch and numeric IDs |
| No **Re-run** button | GitHub only allows re-runs within 30 days | Push a small commit, or add `workflow_dispatch:` to the workflow |
| Image pushed but not in the new repo | Workflow uses a different `ECR_REPOSITORY` value | Match the repository variable to the Terraform repo name |

### Kubernetes

| Symptom | Likely cause | First command |
| --- | --- | --- |
| `ImagePullBackOff` | Wrong image name or tag, or expired ECR token | `kubectl -n netflix describe pod <POD>`, then `sudo /usr/local/bin/refresh-ecr-secret.sh` on the node |
| `CrashLoopBackOff` | App error, wrong env var, Atlas blocking the IP | `kubectl -n netflix logs <POD> --previous` |
| `Pending` | Not enough CPU or memory | `kubectl top nodes` |
| Running but `0/1` ready | Probe on the wrong port or too short a delay | `kubectl -n netflix describe pod <POD>` |
| `404 page not found` | No matching Ingress rule | `kubectl -n netflix describe ingress netflix` |
| kubectl times out | Home IP changed | Update `my_ip_cidr`, `terraform apply` |
| k3s not installed | Boot script failed | `sudo cat /var/log/k3s-bootstrap.log` on the node |

### Argo CD

| Symptom | Likely cause | First command |
| --- | --- | --- |
| Repo `Failed` / `ComparisonError` | Deploy key or repo URL wrong | `argocd repo list` |
| App stays `OutOfSync` | Manual edit or a field Kubernetes changes itself | `argocd app diff netflix` |
| New commit, no change in cluster | Not polled yet (default about 3 minutes) | `argocd app sync netflix` |
| Tag changed in Git, old image running | `images.name` does not match the image in the Deployment | `kubectl kustomize k8s` |
| CI `git push` permission denied | Deploy key without write access | Check the `ci-write` key settings |

---

## 18. Security decisions

| Area | Decision |
| --- | --- |
| AWS credentials (local) | `aws login` temporary credentials, no long lived access keys, never root |
| AWS credentials (CI) | GitHub OIDC, no stored AWS keys |
| CI roles | One role per pipeline, each scoped to one repo and the `main` branch, with `aud` and `sub` conditions |
| Repo identity | Trust policy `sub` includes immutable owner and repo IDs |
| Terraform state | S3, versioned, encrypted, public access blocked, native locking |
| Secrets in Git | None: `.gitignore` covers state, tfvars, plans, kubeconfigs and keys |
| Network | Only 80 and 443 public; SSH and Kubernetes API limited to one IP |
| Node | IMDSv2 required, hop limit 1, encrypted root volume, ECR read only role |
| Images | Scan on push, lifecycle policy, commit SHA tags |
| Database | Atlas allows only the node's IP; connection string only in a Kubernetes Secret |
| Cluster access | kubeconfig kept outside the repo with `600` permissions |
| Argo CD | Never exposed publicly; initial admin secret deleted; read only repo key |
| Supply chain | Terraform from HashiCorp's signed repo; verified VS Code extensions only |

### Known gaps (acceptable for learning, not for production)

| Gap | Production approach |
| --- | --- |
| Single node, single AZ | Multiple nodes across AZs, or EKS |
| Public subnet with SSH | Private subnets, NAT, SSM Session Manager, no SSH |
| HTTP only | TLS with cert-manager and a domain |
| Kubernetes Secrets are base64, not encrypted | AWS Secrets Manager with External Secrets Operator |
| CI pushes directly to `main` in `netflix-infra` | Branch protection; CI opens a pull request |
| Argo CD `admin` account | SSO, `admin` disabled |
| `MUTABLE` image tags | `IMMUTABLE` after removing `latest` |

---

## 19. Lessons learned

These are the things this project actually taught me, mostly by getting them wrong first.

1. **Read the error, not just the colour.** A red dot can mean success (`ssh -T` always exits 1), and a green `Success!` can be meaningless. I once validated an empty folder and got `Success!` because I was one directory too high.
2. **The first error is the one that matters.** I ran four Terraform commands at once, and the screen filled with errors from the last two. The real problem was that `terraform init` had failed at the top, and its message had scrolled away.
3. **Check the prompt before every command.** Most of my wrong results came from running a command in the wrong place: Windows instead of Linux, or the wrong folder.
4. **Verify with the source of truth.** A success message, a commit or a saved file is only a claim. `aws ... get-*` and a `terraform plan` that says `No changes` are proof.
5. **A commit is not a deploy.** Code in Git changes nothing in AWS until `terraform apply` runs. I learned to check AWS directly after every change.
6. **Investigate before assuming.** My frontend pipeline had worked even though the trust policy I imported did not allow it. Following that up revealed a second IAM role I had forgotten I created.
7. **Generated code needs review.** Terraform's import feature wrote the OIDC URL without `https://`, and later, while editing, I accidentally deleted the `aud` condition. I caught both by reading the code line by line and checking AWS.
8. **Least privilege can mean more resources, not fewer.** At first I merged both pipelines into one role. Two roles, each limited to one repo, turned out to be the safer design, so I changed it back.
9. **Do not follow suggested commands blindly.** Error messages suggested `sudo apt install wsl`, `snap install terraform`, `-lock=false` and a VS Code Quick Fix. Each one would have made things worse.
10. **Short lived credentials expire, by design.** Seeing `ExpiredToken` used to feel like something broke. Now I know it is the security model working.
11. **Things will break around the project, not just in it.** A WSL update froze my whole environment before I wrote a single line of Terraform. Fixing that taught me to find the stuck layer instead of reinstalling everything.

---

## 20. Future improvements

- [ ] HTTPS with cert-manager and a custom domain
- [ ] External Secrets Operator with AWS Secrets Manager
- [ ] Checkov or tfsec scanning of Terraform in CI
- [ ] Trivy image scanning in the app pipelines
- [ ] A Terraform CI pipeline: `fmt`, `validate`, `plan` on pull requests
- [ ] Branch protection on `netflix-infra`; CI opens pull requests instead of pushing
- [ ] Remove SSH in favour of SSM Session Manager
- [ ] Prometheus and Grafana for metrics, with alerts
- [ ] Move to EKS with multiple nodes across Availability Zones
- [ ] Pin the k3s version in user data
- [ ] Switch ECR repos to `IMMUTABLE` tags

---

## 21. References

- [Terraform install](https://developer.hashicorp.com/terraform/install)
- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform import blocks](https://developer.hashicorp.com/terraform/language/import)
- [AWS provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CLI: login with console credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html)
- [GitHub Actions: OIDC with AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [k3s documentation](https://docs.k3s.io/)
- [Install kubectl on Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [Argo CD getting started](https://argo-cd.readthedocs.io/en/latest/getting_started/)
- [Kustomize](https://kubectl.docs.kubernetes.io/references/kustomize/)

---


If you are a recruiter or engineer reading this and have feedback on the design, I would genuinely like to hear it.
