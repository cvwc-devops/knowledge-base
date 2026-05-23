DevOps Deep Dive · Infrastructure as Code · CI/CD

# Ship It Right: Node.js → AWS with Terraform & GitHub Actions

Stop clicking through the AWS console. Here's the complete, production-ready playbook to provision your cloud, containerize your app, and automate every deploy — from zero to live.

DevOps Engineer Audience · ~45 min read · Full Code Examples Included · May 2026

Node.js 22, Terraform 1.8, AWS ECS / ECR, GitHub Actions

Table of Contents

[01. Why This Stack Wins](#s1)
[02. Architecture Blueprint](#s2)
[03. The Node.js App](#s3)
[04. Dockerize It Right](#s4)
[05. Terraform: The Foundation](#s5)
[06. Terraform: ECS + ALB](#s6)
[07. GitHub Actions Pipeline](#s7)
[08. Secrets & IAM Right-Sizing](#s8)
[09. Monitoring & Observability](#s9)
[10. Multi-Env: Dev/Stage/Prod](#s10)
[11. Rollback & Zero-Downtime](#s11)
[12. Cost Controls & Cleanup](#s12)
[13. Troubleshooting Guide](#s13)
[14. What's Next](#s14)

Let's skip the fluff. You've got a Node.js app. You want it on AWS. You want infrastructure you can version-control, tear down, and rebuild in minutes. And you want every merge to `main` to automatically ship — no manual steps, no missed configs, no 2 AM console clicking.

That's exactly what this guide builds. By the end, you'll have a complete, production-grade deployment pipeline using **Terraform for infrastructure**, **Docker for packaging**, **AWS ECS Fargate for container orchestration**, and **GitHub Actions for CI/CD automation**. Everything is real code you can copy, adapt, and own.

> "The best infrastructure is one you can rebuild from scratch in 20 minutes — because at some point, you'll have to."
> — Every on-call engineer, eventually

#### ⚡ What You'll Build

- A production Node.js REST API containerized with Docker
- VPC, subnets, security groups, and ECR — all provisioned by Terraform
- ECS Fargate cluster with an Application Load Balancer
- GitHub Actions pipeline: test → build → push → deploy, on every push
- Secrets management via AWS Secrets Manager + SSM Parameter Store
- CloudWatch logging and basic alerting
- Multi-environment setup: dev, staging, prod with Terraform workspaces
- Zero-downtime rolling deployments and one-command rollback

Section 01

## Why This Stack Wins

Before writing a single line of Terraform, it's worth understanding *why* this particular combination of tools is the right call for 90% of production Node.js workloads in 2026.

### The Old Way: Pain Points You Already Know

The classic deployment story goes like this: SSH into an EC2 instance, `git pull`, pray `npm install` doesn't break, `pm2 restart app`, and hope nothing changed in the environment since last time. It works — until it doesn't. Snowflake servers accumulate undocumented tweaks. Rollbacks are a nightmare. Scaling means manually launching more instances and running setup scripts by hand.

Even "better" approaches like baking AMIs or using Elastic Beanstalk improve some of this, but they introduce their own friction: slow feedback loops, opaque configuration, and limited control over the underlying infra.

### The Modern Way: Infrastructure as Code + Containers + GitOps

The stack in this guide flips every one of those problems:

| Old Problem | This Stack's Solution |
| --- | --- |
| Snowflake servers | Immutable Docker images — same everywhere, always |
| Manual deploys | GitHub Actions triggers on every push to `main` |
| Config drift | Terraform state tracks every infrastructure resource |
| Rollbacks = pain | Previous task definition revision re-deployed in one command |
| Scaling = manual | ECS auto-scaling policies adjust desired count automatically |
| "Works on my machine" | Docker ensures dev ≈ staging ≈ prod parity |
| Security? What creds? | IAM roles, no static keys; OIDC for GitHub→AWS trust |

### Why ECS Fargate Over EKS?

Kubernetes is powerful, but for most teams it's overcomplicated for running a Node.js API. ECS Fargate gives you container orchestration without managing control planes or worker nodes. You define a task definition, ECS runs the container on managed compute, and you pay per vCPU/memory-second. It's the right level of abstraction for most production apps.

When you outgrow ECS Fargate — and you'll know when — the Terraform patterns here translate cleanly to EKS. So you're not painting yourself into a corner.

### Why Terraform Over AWS CDK, CloudFormation, or Pulumi?

Terraform's HCL is declarative, readable, and well-understood by essentially every DevOps engineer you'll hire. The provider ecosystem is mature and comprehensive. State management is battle-tested. The `plan`/`apply` workflow makes infrastructure changes auditable and reviewable. AWS CDK is excellent if your team is TypeScript-native and prefers imperative code; CloudFormation is verbose and YAML-heavy; Pulumi is great but has a smaller community. Terraform is the pragmatic choice for a mixed team or any organization that values broad tooling knowledge over language-specific patterns.

#### 📌 Section Takeaways

- Immutable containers + IaC eliminate the "snowflake server" problem permanently
- ECS Fargate is the right container orchestration for most Node.js APIs
- Terraform's plan/apply loop makes infrastructure changes safe and reviewable
- GitHub Actions OIDC eliminates static AWS access keys from your CI pipeline

Section 02

## Architecture Blueprint

Here's the full system at a glance. Every box in this diagram will be provisioned by Terraform or orchestrated by GitHub Actions.

```
┌─────────────────────────────────────────────────────────────────────┐
│                          GitHub Repository                          │
│                                                                     │
│   ┌──────────────┐    push to main    ┌──────────────────────────┐  │
│   │  Developer   │ ──────────────────▶│    GitHub Actions CI/CD  │  │
│   │  Workstation │                    │                          │  │
│   └──────────────┘                    │  1. npm test             │  │
│                                       │  2. docker build         │  │
│                                       │  3. docker push → ECR    │  │
│                                       │  4. ecs update-service   │  │
│                                       └──────────┬───────────────┘  │
└──────────────────────────────────────────────────┼──────────────────┘
                                                   │ OIDC → IAM Role
                                                   ▼
┌─────────────────────── AWS Account ──────────────────────────────────┐
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                        VPC (10.0.0.0/16)                     │   │
│  │                                                              │   │
│  │  ┌─────────────────────┐    ┌─────────────────────────┐     │   │
│  │  │  Public Subnet AZ-a │    │   Public Subnet AZ-b    │     │   │
│  │  │  10.0.1.0/24        │    │   10.0.2.0/24           │     │   │
│  │  │                     │    │                         │     │   │
│  │  │  ┌───────────────┐  │    │  ┌───────────────────┐  │     │   │
│  │  │  │      ALB      │  │    │  │       ALB         │  │     │   │
│  │  │  │  (port 80/443)│  │    │  │    (port 80/443)  │  │     │   │
│  │  │  └───────┬───────┘  │    │  └─────────┬─────────┘  │     │   │
│  │  └──────────┼──────────┘    └────────────┼────────────┘     │   │
│  │             │                            │                   │   │
│  │  ┌──────────▼──────────────────────────▼──────────────┐     │   │
│  │  │            Private Subnets (10.0.3.0/24, etc.)     │     │   │
│  │  │                                                    │     │   │
│  │  │         ┌─────────────────────────────┐            │     │   │
│  │  │         │      ECS Fargate Cluster    │            │     │   │
│  │  │         │                             │            │     │   │
│  │  │         │  ┌──────────┐ ┌──────────┐  │            │     │   │
│  │  │         │  │ Task 1   │ │ Task 2   │  │            │     │   │
│  │  │         │  │ Node.js  │ │ Node.js  │  │            │     │   │
│  │  │         │  │ :3000    │ │ :3000    │  │            │     │   │
│  │  │         │  └──────────┘ └──────────┘  │            │     │   │
│  │  │         └─────────────────────────────┘            │     │   │
│  │  │                      │                             │     │   │
│  │  │    ┌─────────────────┼────────────┐                │     │   │
│  │  │    │                 │            │                │     │   │
│  │  │  ┌─▼──────────┐  ┌───▼──────┐  ┌─▼──────────┐    │     │   │
│  │  │  │  RDS/Aurora│  │Secrets   │  │  CloudWatch│    │     │   │
│  │  │  │  Postgres  │  │Manager   │  │  Logs+Alarms│   │     │   │
│  │  │  └────────────┘  └──────────┘  └────────────┘    │     │   │
│  │  └───────────────────────────────────────────────────┘     │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌────────────────────────────────┐                                  │
│  │   ECR (Elastic Container Reg) │ ◀── docker push from GH Actions  │
│  └────────────────────────────────┘                                  │
└──────────────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

**Private subnets for ECS tasks.** Your containers never get a public IP. Traffic flows in through the ALB (which lives in public subnets), and outbound traffic from containers goes through a NAT Gateway. This is proper defense-in-depth.

**Multi-AZ from day one.** The ALB and ECS tasks are distributed across two Availability Zones. If one AZ has an outage, your app keeps running. This isn't optional for production.

**ECR as your private image registry.** AWS ECR integrates natively with IAM, ECS, and your GitHub Actions workflow. No DockerHub rate limits, no external registry to manage.

**GitHub OIDC for CI/CD credentials.** No static AWS access keys stored in GitHub Secrets. Instead, GitHub Actions requests a short-lived token via OIDC that assumes an IAM role. It's the right way to do this in 2026.

💡 Prerequisites Checklist

- AWS account with admin access (or a permission set that covers VPC, ECS, ECR, IAM, CloudWatch)
- Terraform ≥ 1.7 installed locally
- AWS CLI v2 configured (`aws configure`)
- Docker Desktop running locally
- Node.js 20+ for local development
- GitHub repository for your project

Section 03

## The Node.js Application

We'll use a realistic Express API as our deployment target — one with proper health check endpoints, environment-aware config, structured logging, and a database connection. Not just a hello-world.

### Project Structure

*SHELL — Project Layout*

```
my-api/
├── src/
│   ├── app.js           # Express app setup
│   ├── server.js        # Entry point
│   ├── routes/
│   │   ├── health.js    # /health and /ready endpoints
│   │   ├── users.js     # Business logic routes
│   │   └── index.js     # Route aggregator
│   ├── middleware/
│   │   ├── errorHandler.js
│   │   └── requestLogger.js
│   ├── config/
│   │   └── index.js     # Environment-aware config
│   └── db/
│       └── client.js    # DB connection pool
├── test/
│   ├── unit/
│   └── integration/
├── Dockerfile
├── .dockerignore
├── package.json
└── package-lock.json
```

### package.json

*JSON — package.json*

```
{
  "name": "my-api",
  "version": "1.0.0",
  "description": "Production Node.js REST API",
  "main": "src/server.js",
  "engines": {
    "node": ">=20.0.0"
  },
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "test": "jest --coverage --forceExit",
    "test:unit": "jest test/unit",
    "test:integration": "jest test/integration",
    "lint": "eslint src/"
  },
  "dependencies": {
    "express": "^4.19.2",
    "pg": "^8.11.3",
    "dotenv": "^16.4.5",
    "pino": "^9.2.0",
    "pino-http": "^10.2.0",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "express-rate-limit": "^7.2.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "supertest": "^7.0.0",
    "nodemon": "^3.1.3",
    "eslint": "^8.57.0"
  }
}
```

### src/config/index.js — Environment Config

*JavaScript — src/config/index.js*

```
// Load .env only in local development
if (process.env.NODE_ENV !== 'production') {
  require('dotenv').config();
}

const config = {
  env:  process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,

  db: {
    host:     process.env.DB_HOST,
    port:     parseInt(process.env.DB_PORT, 10) || 5432,
    name:     process.env.DB_NAME,
    user:     process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    poolMin:  parseInt(process.env.DB_POOL_MIN, 10) || 2,
    poolMax:  parseInt(process.env.DB_POOL_MAX, 10) || 10,
  },

  log: {
    level: process.env.LOG_LEVEL || 'info',
  },

  rateLimit: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max:      parseInt(process.env.RATE_LIMIT_MAX, 10) || 100,
  },
};

// Fail fast on missing required config in production
const required = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD'];

if (config.env === 'production') {
  required.forEach(key => {
    if (!process.env[key]) {
      console.error(`FATAL: Missing required env var: ${key}`);
      process.exit(1);
    }
  });
}

module.exports = config;
```

### src/app.js — Express Application

*JavaScript — src/app.js*

```
const express      = require('express');
const helmet       = require('helmet');
const compression  = require('compression');
const rateLimit    = require('express-rate-limit');
const pinoHttp     = require('pino-http');
const config       = require('./config');
const routes       = require('./routes');
const errorHandler = require('./middleware/errorHandler');
const { logger }   = require('./middleware/requestLogger');

const app = express();

// Security headers
app.use(helmet());

// Structured request logging
app.use(pinoHttp({ logger }));

// Gzip responses
app.use(compression());

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting — skip /health to not affect ALB health checks
const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max:      config.rateLimit.max,
  skip:     (req) => req.path === '/health' || req.path === '/ready',
  standardHeaders: true,
  legacyHeaders:   false,
});
app.use(limiter);

// Routes
app.use('/', routes);

// Global error handler — must be last
app.use(errorHandler);

module.exports = { app, logger };
```

### src/routes/health.js — Health & Readiness Endpoints

⚠️ Critical: Get Health Checks Right

ECS and the ALB use health check endpoints to decide whether a task is healthy. If your health check is wrong, ECS will keep restarting your tasks or the ALB will drain connections at the worst moment. The pattern below separates liveness from readiness — a distinction ECS doesn't enforce natively, but is good hygiene.

*JavaScript — src/routes/health.js*

```
const router  = require('express').Router();
const { pool } = require('../db/client');

// Liveness — is the process alive?
// Returns 200 as long as Node is running.
// ALB will route traffic here every 30 seconds.
router.get('/health', (req, res) => {
  res.status(200).json({
    status:    'ok',
    timestamp: new Date().toISOString(),
    uptime:    process.uptime(),
    version:   process.env.APP_VERSION || 'unknown',
  });
});

// Readiness — is the app ready to serve traffic?
// Checks database connectivity. Returns 503 if not ready.
// ECS task won't receive traffic until this returns 200.
router.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({
      status:   'ready',
      database: 'connected',
    });
  } catch (err) {
    res.status(503).json({
      status:   'not ready',
      database: 'disconnected',
      error:    err.message,
    });
  }
});

module.exports = router;
```

### src/server.js — Graceful Startup & Shutdown

*JavaScript — src/server.js*

```
const { app, logger } = require('./app');
const config         = require('./config');

const server = app.listen(config.port, () => {
  logger.info({ port: config.port, env: config.env },
    'Server started');
});

// ── Graceful shutdown ──────────────────────────────────────────────
// ECS sends SIGTERM before terminating a task.
// We stop accepting new connections, finish in-flight requests,
// then exit cleanly. This prevents dropped requests during deploys.

const shutdown = (signal) => {
  logger.info({ signal }, 'Shutdown signal received');

  server.close((err) => {
    if (err) {
      logger.error(err, 'Error during shutdown');
      process.exit(1);
    }
    logger.info('Server closed cleanly');
    process.exit(0);
  });

  // Force exit after 15s if graceful shutdown stalls
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 15_000).unref();
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason) => {
  logger.error({ reason }, 'Unhandled rejection');
  process.exit(1);
});
```

#### 📌 Section Takeaways

- Separate `/health` (liveness) from `/ready` (readiness) — ALB uses the former, ECS uses both
- Handle SIGTERM for graceful shutdown — ECS sends this before killing a task
- Fail fast on missing env vars in production — silent misconfigurations are hard to debug at 2 AM
- Use structured JSON logging (Pino) from the start — CloudWatch Logs Insights parses it automatically

Section 04

## Dockerize It Right

A Dockerfile is not just packaging. It's also a security surface, a performance concern, and a build reproducibility guarantee. The multi-stage Dockerfile below gets all three right.

### Dockerfile — Multi-Stage Production Build

*DOCKERFILE*

```
# ─── Stage 1: Dependency installation ────────────────────────────
# Uses a full Node image to install deps, then discards dev layers
FROM node:22-alpine3.19 AS deps

WORKDIR /app

# Copy only manifests first — Docker layer caching means
# npm install re-runs ONLY when package*.json changes
COPY package.json package-lock.json ./

RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force

# ─── Stage 2: Test runner (only used in CI) ───────────────────────
FROM node:22-alpine3.19 AS test

WORKDIR /app

COPY package.json package-lock.json ./
# Install ALL deps including devDependencies for tests
RUN npm ci --ignore-scripts && npm cache clean --force

COPY . .

RUN npm test

# ─── Stage 3: Production image ────────────────────────────────────
FROM node:22-alpine3.19 AS production

# Install security updates
RUN apk upgrade --no-cache

# Create non-root user — NEVER run Node as root in production
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only production deps from deps stage
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules

# Copy source code
COPY --chown=appuser:appgroup src/ ./src/
COPY --chown=appuser:appgroup package.json ./

# Drop to non-root user
USER appuser

# Expose the port your app listens on
EXPOSE 3000

# Use the full path — more explicit, avoids PATH surprises
CMD ["node", "src/server.js"]

# Build-time metadata labels
LABEL org.opencontainers.image.title="my-api" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/your-org/my-api"
```

### .dockerignore — Keep Your Images Lean

*.dockerignore*

```
node_modules
.git
.gitignore
*.md
.env
.env.*
coverage/
.nyc_output/
test/
*.test.js
*.spec.js
Dockerfile*
docker-compose*
.github/
terraform/
*.log
.DS_Store
dist/
```

### Build & Test Locally

*SHELL*

```
# Build the production image
docker build --target production -t my-api:local .

# Run it locally with env vars
docker run -p 3000:3000 \
  -e NODE_ENV=production \
  -e DB_HOST=host.docker.internal \
  -e DB_NAME=mydb \
  -e DB_USER=admin \
  -e DB_PASSWORD=secret \
  my-api:local

# Verify health endpoint
curl http://localhost:3000/health
# {"status":"ok","timestamp":"2026-05-22T...","uptime":1.2,"version":"unknown"}

# Check image size — should be under 200MB
docker images my-api:local --format "{{.Size}}"
```

✅ Pro Tip: Image Size Matters

Alpine-based images are typically 150-200MB for a Node.js app. That matters because ECR pull time directly affects cold-start latency for new ECS tasks. If your image balloons past 500MB, look for accidentally included `node_modules` or missing `.dockerignore` entries.

### docker-compose.yml — Local Development

*YAML — docker-compose.yml*

```
version: '3.9'

services:
  api:
    build:
      context: .
      target: production
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=mydb
      - DB_USER=admin
      - DB_PASSWORD=secret
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    environment:
      - POSTGRES_DB=mydb
      - POSTGRES_USER=admin
      - POSTGRES_PASSWORD=secret
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

#### 📌 Section Takeaways

- Multi-stage builds are non-negotiable — they separate test deps from production artifacts
- Always run Node as a non-root user in production containers
- Layer ordering matters: copy `package*.json` first, code second — maximizes Docker cache hits
- A tight `.dockerignore` prevents test files, credentials, and git history from entering the image

Section 05

## Terraform: The Foundation

Terraform files are organized into logical modules. We'll build everything in a flat structure first (easier to understand), then show how to modularize for multi-environment use in Section 10.

### Terraform Project Structure

*SHELL — Terraform Layout*

```
terraform/
├── main.tf            # Root module, AWS provider config
├── variables.tf       # Input variable declarations
├── outputs.tf         # Output values
├── versions.tf        # Required providers + version constraints
├── vpc.tf             # VPC, subnets, IGW, NAT Gateway, route tables
├── security.tf        # Security groups
├── ecr.tf             # Elastic Container Registry
├── ecs.tf             # ECS Cluster, Task Definition, Service
├── alb.tf             # Application Load Balancer
├── iam.tf             # IAM roles and policies
├── cloudwatch.tf      # Log groups, metric alarms
├── secrets.tf         # Secrets Manager entries
├── rds.tf             # RDS PostgreSQL (optional)
└── terraform.tfvars   # Variable values (gitignored for prod)
```

### versions.tf — Pin Your Providers

*HCL — versions.tf*

```
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state — use S3 backend in production
  # Uncomment and fill in before running terraform init
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "my-api/production/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}
```

### main.tf — Provider + Locals

*HCL — main.tf*

```
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}
```

### variables.tf — Input Variables

*HCL — variables.tf*

```
variable "aws_region" {
  type        = string
  description = "AWS region for all resources"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev | staging | prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  type        = string
  description = "Team or person responsible for this deployment"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "container_cpu" {
  type        = number
  description = "Fargate task CPU units (256=0.25vCPU, 512, 1024, 2048, 4096)"
  default     = 512
}

variable "container_memory" {
  type        = number
  description = "Fargate task memory in MiB"
  default     = 1024
}

variable "desired_count" {
  type        = number
  description = "Number of ECS task instances to run"
  default     = 2
}

variable "github_org" {
  type        = string
  description = "GitHub organization for OIDC trust"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name for OIDC trust"
}
```

### vpc.tf — Networking

*HCL — vpc.tf*

```
# Fetch available AZs in the configured region
data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC ───────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

# ── Public Subnets (ALB lives here) ───────────────────────────────
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name_prefix}-public-${count.index + 1}" }
}

# ── Private Subnets (ECS tasks live here) ─────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "${local.name_prefix}-private-${count.index + 1}" }
}

# ── Internet Gateway ──────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

# ── Elastic IPs for NAT Gateways ──────────────────────────────────
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-nat-eip-${count.index + 1}" }
}

# ── NAT Gateways (one per AZ for HA) ─────────────────────────────
resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${local.name_prefix}-nat-${count.index + 1}" }
  depends_on = [aws_internet_gateway.main]
}

# ── Public Route Table ────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Tables (one per AZ, each pointing to its NAT GW) ─
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = { Name = "${local.name_prefix}-private-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

### security.tf — Security Groups

*HCL — security.tf*

```
# ── ALB Security Group ────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB: accept HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = { Name = "${local.name_prefix}-alb-sg" }
}

# ── ECS Task Security Group ───────────────────────────────────────
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "ECS tasks: accept traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "From ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound (for ECR pull, Secrets Manager, etc.)"
  }

  tags = { Name = "${local.name_prefix}-ecs-tasks-sg" }
}
```

### ecr.tf — Container Registry

*HCL — ecr.tf*

```
resource "aws_ecr_repository" "app" {
  name                 = "${local.name_prefix}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true   # Scans for CVEs on every push
  }

  tags = { Name = "${local.name_prefix}-ecr" }
}

# Lifecycle policy: keep last 10 production images, expire untagged
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
```

#### 📌 Section Takeaways

- Pin your Terraform provider versions — minor AWS provider updates can introduce breaking changes
- Use S3 backend with DynamoDB locking for state — never use local state on a team project
- One NAT Gateway per AZ is the HA-correct approach (costs more, but avoids cross-AZ traffic charges during AZ failures)
- ECS tasks should live in private subnets — the ALB is their only public-facing entry point
- ECR lifecycle policies prevent your registry from growing unbounded and costing money

Section 06

## Terraform: ECS Cluster, Tasks & ALB

This is the heart of the infrastructure. The ECS service pulls your Docker image, runs it as tasks in private subnets, and the ALB distributes traffic to healthy tasks.

### iam.tf — Task Execution and Task Roles

*HCL — iam.tf*

```
# ── ECS Task Execution Role ───────────────────────────────────────
# Used by ECS AGENT to pull images from ECR and push logs to CloudWatch
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow task execution role to read secrets from Secrets Manager
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "read-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "secretsmanager:GetSecretValue",
        "ssm:GetParameters",
        "kms:Decrypt"
      ]
      Resource = [
        aws_secretsmanager_secret.db_password.arn,
        "arn:aws:ssm:${var.aws_region}:*:parameter/${local.name_prefix}/*"
      ]
    }]
  })
}

# ── ECS Task Role ─────────────────────────────────────────────────
# Used by your APPLICATION CODE — what permissions does your app need?
resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Add S3, SQS, DynamoDB etc. permissions HERE for your app's task role
# Keep this minimal — principle of least privilege

# ── GitHub Actions OIDC Provider ──────────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# IAM Role that GitHub Actions assumes via OIDC
resource "aws_iam_role" "github_actions" {
  name = "${local.name_prefix}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Only allow the specific repo, not all of GitHub
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })
}

# Permissions the GitHub Actions role needs
resource "aws_iam_role_policy" "github_actions" {
  name = "deploy-permissions"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassExecutionRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      }
    ]
  })
}
```

### ecs.tf — Cluster, Task Definition, Service

*HCL — ecs.tf*

```
# ── ECS Cluster ───────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name_prefix}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ── CloudWatch Log Group ──────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30

  tags = { Name = "${local.name_prefix}-logs" }
}

# ── ECS Task Definition ───────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${aws_ecr_repository.app.repository_url}:latest"

      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]

      environment = [
        { name = "NODE_ENV",  value = "production" },
        { name = "PORT",      value = tostring(var.container_port) },
        { name = "DB_HOST",   value = aws_db_instance.postgres.address },
        { name = "DB_PORT",   value = "5432" },
        { name = "DB_NAME",   value = "appdb" },
        { name = "DB_USER",   value = "appuser" },
      ]

      # Secrets from Secrets Manager — injected as env vars at runtime
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O- http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }

      essential = true

      # Resource limits within the task
      cpu    = var.container_cpu
      memory = var.container_memory
    }
  ])

  tags = { Name = "${local.name_prefix}-task-definition" }
}

# ── ECS Service ───────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Rolling update deployment configuration
  deployment_circuit_breaker {
    enable   = true
    rollback = true   # Auto-rollback if deploy fails
  }

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution
  ]

  # Ignore task definition changes — GitHub Actions manages this
  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = { Name = "${local.name_prefix}-service" }
}
```

### alb.tf — Application Load Balancer

*HCL — alb.tf*

```
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.environment == "prod"

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-access-logs"
    enabled = true
  }

  tags = { Name = "${local.name_prefix}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"   # Required for Fargate awsvpc networking

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  tags = { Name = "${local.name_prefix}-tg" }
}

# HTTP listener — redirects to HTTPS in production
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.environment == "prod" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.environment == "prod" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.environment != "prod" ? [1] : []
      content {
        target_group {
          arn    = aws_lb_target_group.app.arn
          weight = 1
        }
      }
    }
  }
}
```

### outputs.tf — Useful Values

*HCL — outputs.tf*

```
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "ALB DNS name — point your domain CNAME here"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "ECR repository URL for docker push"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value       = aws_ecs_service.app.name
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Add this ARN to GitHub Actions secret: AWS_ROLE_ARN"
  sensitive   = true
}
```

### First Terraform Apply

*SHELL*

```
cd terraform/

# Initialize — downloads providers, sets up backend
terraform init

# Preview what Terraform will create (read this carefully!)
terraform plan \
  -var="project_name=my-api" \
  -var="environment=staging" \
  -var="owner=your-team" \
  -var="github_org=your-org" \
  -var="github_repo=your-repo" \
  -out=tfplan

# Apply — creates ~35 AWS resources
terraform apply tfplan

# Capture outputs you'll need for GitHub Actions
terraform output github_actions_role_arn
terraform output ecr_repository_url
terraform output ecs_cluster_name
terraform output ecs_service_name
```

⚠️ NAT Gateway Cost Warning

Two NAT Gateways cost approximately $64/month each in us-east-1 ($0.045/hour × 2 × 730 hours) plus data transfer. For dev environments, use a single NAT Gateway or NAT instance. The Terraform variable `var.environment` can gate this decision.

#### 📌 Section Takeaways

- Two IAM roles per ECS service: Task Execution Role (for ECS agent) and Task Role (for your app code) — keep them separate and minimal
- GitHub OIDC is the right way to give CI/CD access to AWS — no static keys, ever
- `lifecycle { ignore_changes = [task_definition] }` is critical — without it, Terraform will fight GitHub Actions over task definition control
- Enable ECS Deployment Circuit Breaker with rollback — it auto-reverts failed deployments
- Set `deregistration_delay = 30` on your target group to match your SIGTERM graceful shutdown window

Section 07

## GitHub Actions: The CI/CD Pipeline

This is where everything comes together. The pipeline runs on every push to `main`, and on pull requests (test-only, no deploy). Every step has a purpose — nothing is cargo-culted in.

### GitHub Secrets to Configure

Before setting up the workflow, add these to your GitHub repository's Secrets and Variables (Settings → Secrets and variables → Actions):

| Secret Name | Value | Notes |
| --- | --- | --- |
| `AWS_ROLE_ARN` | From `terraform output github_actions_role_arn` | The OIDC role ARN Terraform created |
| `AWS_REGION` | `us-east-1` | Your deployment region |
| `ECR_REPOSITORY_URL` | From `terraform output ecr_repository_url` | ECR repo URL without the image tag |
| `ECS_CLUSTER_NAME` | From `terraform output ecs_cluster_name` | ECS cluster name |
| `ECS_SERVICE_NAME` | From `terraform output ecs_service_name` | ECS service name |
| `ECS_TASK_DEFINITION_FAMILY` | `my-api-staging-app` | Task definition family name |

### The Main Workflow

*YAML — .github/workflows/deploy.yml*

```
name: CI/CD Pipeline

# Trigger on pushes to main and all pull requests
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:  # Allow manual trigger

env:
  AWS_REGION:              ${{ secrets.AWS_REGION }}
  ECR_REPOSITORY_URL:      ${{ secrets.ECR_REPOSITORY_URL }}
  ECS_CLUSTER:             ${{ secrets.ECS_CLUSTER_NAME }}
  ECS_SERVICE:             ${{ secrets.ECS_SERVICE_NAME }}
  TASK_DEFINITION_FAMILY:  ${{ secrets.ECS_TASK_DEFINITION_FAMILY }}
  CONTAINER_NAME:          app

permissions:
  id-token: write   # Required for OIDC JWT token
  contents: read
  pull-requests: write

jobs:

  # ─── Job 1: Run tests ─────────────────────────────────────────────
  test:
    name: Test
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: testuser
          POSTGRES_PASSWORD: testpass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'   # Caches node_modules between runs

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run tests
        env:
          NODE_ENV: test
          DB_HOST: localhost
          DB_PORT: 5432
          DB_NAME: testdb
          DB_USER: testuser
          DB_PASSWORD: testpass
        run: npm test

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage
          path: coverage/

  # ─── Job 2: Build & Push Docker image ────────────────────────────
  build-and-push:
    name: Build & Push
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    outputs:
      image-tag: ${{ steps.meta.outputs.version }}
      image-uri: ${{ steps.build-push.outputs.image-uri }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: GitHubActions-${{ github.run_id }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Set up Docker Buildx (enables build caching)
        uses: docker/setup-buildx-action@v3

      - name: Generate image metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.ECR_REPOSITORY_URL }}
          tags: |
            type=sha,prefix=sha-,format=short
            type=raw,value=latest
            type=raw,value=${{ github.run_number }}

      - name: Build and push Docker image
        id: build-push
        uses: docker/build-push-action@v5
        with:
          context: .
          target: production
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            APP_VERSION=${{ github.sha }}

      - name: Export image URI
        id: export
        run: |
          echo "image-uri=${{ env.ECR_REPOSITORY_URL }}:sha-${{ github.sha }}" >> $GITHUB_OUTPUT

  # ─── Job 3: Deploy to ECS ─────────────────────────────────────────
  deploy:
    name: Deploy to ECS
    runs-on: ubuntu-latest
    needs: build-and-push
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    environment:
      name: staging     # Requires manual approval for 'production' env
      url: ${{ steps.get-url.outputs.url }}

    steps:
      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Download current task definition
        run: |
          aws ecs describe-task-definition \
            --task-definition ${{ env.TASK_DEFINITION_FAMILY }} \
            --query taskDefinition \
            > task-definition.json

      - name: Update task definition with new image
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ needs.build-and-push.outputs.image-uri }}

      - name: Deploy to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true  # Waits until new tasks are healthy
          force-new-deployment: true

      - name: Get ALB URL
        id: get-url
        run: |
          URL=$(aws elbv2 describe-load-balancers \
            --names "${{ env.ECS_CLUSTER }}-alb" \
            --query 'LoadBalancers[0].DNSName' \
            --output text)
          echo "url=http://$URL" >> $GITHUB_OUTPUT

      - name: Smoke test
        run: |
          URL="${{ steps.get-url.outputs.url }}"
          echo "Smoke testing $URL/health"
          for i in {1..5}; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL/health")
            if [ "$STATUS" = "200" ]; then
              echo "✅ Health check passed"
              exit 0
            fi
            echo "Attempt $i failed (status: $STATUS), retrying..."
            sleep 10
          done
          echo "❌ Smoke test failed after 5 attempts"
          exit 1
```

✅ Pipeline Optimization: Build Caching

The `cache-from: type=gha` and `cache-to: type=gha,mode=max` lines use GitHub Actions cache to store Docker build layers. This can cut your build time from 3-4 minutes to under 60 seconds on subsequent runs, since unchanged layers are restored from cache rather than rebuilt.

### Pull Request Workflow — Lightweight CI

*YAML — .github/workflows/pr-checks.yml*

```
name: PR Checks

on:
  pull_request:
    branches: [main, develop]

jobs:
  checks:
    name: Lint, Test & Build Check
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'npm'

      - run: npm ci
      - run: npm run lint
      - run: npm test

      # Verify Docker builds successfully — catch Dockerfile errors on PR
      - name: Build Docker image (no push)
        uses: docker/build-push-action@v5
        with:
          context: .
          target: production
          push: false

      - name: Comment test results on PR
        uses: actions/github-script@v7
        if: always()
        with:
          script: |
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
            });
            const body = `## CI Results\n- Lint: ✅\n- Tests: ✅\n- Docker build: ✅`;
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body,
            });
```

#### 📌 Section Takeaways

- Jobs are chained: test → build → deploy. A test failure blocks everything — no bad code ships
- Use `github.ref == 'refs/heads/main'` to gate deploys — PRs run tests only, never deploy
- GitHub Actions cache for Docker layers is a massive time saver — always set it up
- `wait-for-service-stability: true` makes the pipeline wait for ECS to confirm healthy tasks before marking the deploy successful
- Add a smoke test step after deploy — it's your last line of defense against a broken production release

Section 08

## Secrets & IAM: Doing It Right

Credentials in environment variables are a common mistake. Credentials in Git are a catastrophe. Here's the proper approach using AWS Secrets Manager integrated with ECS task definitions.

### secrets.tf — AWS Secrets Manager

*HCL — secrets.tf*

```
# Create the secret in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "/${local.name_prefix}/db/password"
  description             = "Database password for ${local.name_prefix}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = { Name = "${local.name_prefix}-db-password" }
}

# The actual secret value — managed outside Terraform
# Set this once via CLI or AWS Console, then Terraform won't touch it
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = "PLACEHOLDER_CHANGE_ME"

  lifecycle {
    ignore_changes = [secret_string]  # Don't overwrite manually set values
  }
}

# SSM Parameter Store for non-sensitive config
resource "aws_ssm_parameter" "db_host" {
  name  = "/${local.name_prefix}/db/host"
  type  = "String"
  value = aws_db_instance.postgres.address
}

# Set the real DB password via CLI (run this once after terraform apply)
# aws secretsmanager put-secret-value \
#   --secret-id "/my-api-staging/db/password" \
#   --secret-string "your-real-password-here"
```

### How Secrets Flow to Your Container

In the ECS task definition (shown in Section 6), the `secrets` block injects Secrets Manager values as environment variables at container startup time. The ECS agent (using the Task Execution Role) retrieves the secret value from Secrets Manager and injects it. Your application code just reads `process.env.DB_PASSWORD` — it never sees the Secrets Manager API.

```
GitHub Actions OIDC Token
         │
         ▼
    AWS STS API
         │
         ▼ (short-lived credentials, ~1 hour)
    IAM Role: github-actions-role
         │
    (allowed actions: ECR push, ECS update, iam:PassRole)
         │
         ▼
    ECS Service Update
         │
         ▼
    ECS Agent starts new task
         │
         ▼
    Task Execution Role fetches from Secrets Manager
         │
         ▼ (secret value injected as env var)
    Node.js container reads process.env.DB_PASSWORD
```

🚫 Things You Must Never Do

- Never store AWS credentials in GitHub Secrets as `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` for production — use OIDC
- Never hardcode secrets in Dockerfiles, source code, or task definition JSON
- Never commit `.env` files to Git — add them to `.gitignore` immediately
- Never give your GitHub Actions role broad permissions like `AdministratorAccess` — scope it down to exactly what's needed

#### 📌 Section Takeaways

- Secrets Manager + ECS task secrets injection is the right pattern — zero code changes needed in your app
- Use `lifecycle { ignore_changes = [secret_string] }` to let Terraform create the secret without controlling its value
- OIDC means your CI pipeline never holds a long-lived AWS credential — tokens expire after the job completes
- Keep the GitHub Actions IAM role tightly scoped: ECR push, ECS update, PassRole — nothing else

Section 09

## Monitoring & Observability

Deploying without monitoring is half a job. Here's the CloudWatch setup that gives you visibility from day one.

### cloudwatch.tf — Alarms & Dashboards

*HCL — cloudwatch.tf*

```
# ── SNS Topic for alerts ──────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
}

# Subscribe your team's email to alerts
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "your-team@company.com"
}

# ── ALB 5xx Error Rate Alarm ──────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB returning >10 5xx errors per minute"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# ── ECS Task Count Alarm — alerts if tasks < desired ─────────────
resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks" {
  alarm_name          = "${local.name_prefix}-running-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.desired_count
  alarm_description   = "Running ECS tasks fell below desired count"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
}

# ── ALB Response Time P99 ─────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "${local.name_prefix}-alb-p99-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 2   # Alert if p99 > 2 seconds
  alarm_description   = "P99 response time > 2s"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# ── CloudWatch Dashboard ──────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "ALB Request Rate"
          metrics = [["AWS/ApplicationELB", "RequestCount",
            "LoadBalancer", aws_lb.main.arn_suffix]]
          period  = 60
          stat    = "Sum"
          view    = "timeSeries"
        }
      },
      {
        type = "metric"
        properties = {
          title   = "5xx Error Count"
          metrics = [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count",
            "LoadBalancer", aws_lb.main.arn_suffix]]
          period  = 60
          stat    = "Sum"
        }
      },
      {
        type = "log"
        properties = {
          title   = "Recent Application Errors"
          query   = "SOURCE '/ecs/${local.name_prefix}' | fields @timestamp, @message | filter level = 'error' | sort @timestamp desc | limit 50"
          region  = var.aws_region
          view    = "table"
        }
      }
    ]
  })
}
```

### CloudWatch Logs Insights Queries

Paste these into CloudWatch Logs Insights, pointed at your `/ecs/your-app-name` log group:

*CWL Insights — Useful Queries*

```
-- Error rate over time
fields @timestamp, @message
| filter level = "error"
| stats count() as errors by bin(5m)
| sort @timestamp desc

-- Slowest requests
fields @timestamp, req.method, req.url, res.responseTime
| filter res.responseTime > 1000
| sort res.responseTime desc
| limit 20

-- Request distribution by route
fields req.url
| stats count() as requests by req.url
| sort requests desc
```

#### 📌 Section Takeaways

- Enable Container Insights on your ECS cluster — it provides CPU, memory, and task-count metrics out of the box
- Alarm on ALB 5xx count, not rate — a sudden spike of errors matters even if it's a small percentage
- Structured JSON logging (Pino) unlocks CloudWatch Logs Insights filtering and aggregation
- P99 latency alarms catch tail latency issues that averages hide

Section 10

## Multi-Environment: Dev / Staging / Prod

The pattern so far works for one environment. Here's how to extend it cleanly to dev, staging, and production using Terraform workspaces and per-environment variable files.

### Approach 1: Terraform Workspaces + tfvars

*SHELL*

```
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch and apply with environment-specific vars
terraform workspace select staging
terraform apply -var-file=environments/staging.tfvars
```

*HCL — environments/prod.tfvars*

```
environment           = "prod"
project_name          = "my-api"
owner                 = "platform-team"
aws_region            = "us-east-1"
desired_count         = 3
container_cpu         = 1024
container_memory      = 2048
vpc_cidr              = "10.2.0.0/16"
public_subnet_cidrs   = ["10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs  = ["10.2.3.0/24", "10.2.4.0/24"]
github_org            = "your-org"
github_repo           = "your-repo"
```

*HCL — environments/dev.tfvars*

```
environment           = "dev"
project_name          = "my-api"
owner                 = "your-name"
aws_region            = "us-east-1"
desired_count         = 1       # Save cost in dev
container_cpu         = 256
container_memory      = 512
# Single NAT GW for dev — use a locals conditional to gate this
github_org            = "your-org"
github_repo           = "your-repo"
```

### Approach 2: Module-Per-Environment (More Explicit)

*SHELL — Modules Layout*

```
terraform/
├── modules/
│   ├── networking/     # VPC, subnets, IGW, NAT
│   ├── ecs-service/    # ECS cluster, task def, service
│   ├── alb/            # ALB, target group, listeners
│   ├── ecr/            # ECR repository + lifecycle
│   └── iam/            # IAM roles for ECS + GitHub
├── environments/
│   ├── dev/
│   │   ├── main.tf     # Calls modules with dev config
│   │   └── backend.tf  # Dev-specific S3 state bucket
│   ├── staging/
│   │   ├── main.tf
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       └── backend.tf
```

*HCL — environments/staging/main.tf*

```
module "networking" {
  source = "../../modules/networking"

  project_name         = "my-api"
  environment          = "staging"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
}

module "ecs_service" {
  source = "../../modules/ecs-service"

  project_name      = "my-api"
  environment       = "staging"
  vpc_id            = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  ecr_repository_url = module.ecr.repository_url
  desired_count     = 2
  container_cpu     = 512
  container_memory  = 1024
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = "my-api"
  environment  = "staging"
}
```

### Multi-Environment GitHub Actions

*YAML — Multi-env deploy job structure*

```
jobs:
  test:
    # ... same as before ...

  build-and-push:
    needs: test
    # ... same as before ...

  deploy-staging:
    name: Deploy → Staging
    needs: build-and-push
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.STAGING_AWS_ROLE_ARN }}
          aws-region: us-east-1
      # ... deploy steps using STAGING_ prefixed secrets ...

  deploy-prod:
    name: Deploy → Production
    needs: deploy-staging
    environment: production  # Requires manual approval in GitHub
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.PROD_AWS_ROLE_ARN }}
          aws-region: us-east-1
      # ... deploy steps using PROD_ prefixed secrets ...
```

💡 GitHub Environment Protection Rules

Set up the `production` GitHub Environment (Settings → Environments → production) with required reviewers. This gates the production deploy behind a manual approval step — no code reaches production without a human sign-off. The pipeline pauses and sends a Slack/email notification to the specified reviewers.

#### 📌 Section Takeaways

- Workspaces + tfvars is simpler for small teams; module-per-environment gives more isolation and clarity at scale
- Use separate IAM roles per environment — staging and prod should have completely separate AWS credentials
- GitHub Environment protection rules are your production gate — require at least one reviewer approval
- Always deploy to staging before production — let staging bake for at least the time it takes to run your smoke tests

Section 11

## Rollbacks & Zero-Downtime Deployments

Deployments break. The question is: how fast can you recover? With this setup, you have multiple layers of protection.

### ECS Deployment Circuit Breaker (Automatic)

Already configured in `ecs.tf` with `deployment_circuit_breaker { enable = true, rollback = true }`. If more than half of your new tasks fail their health check within the deployment, ECS automatically rolls back to the previous task definition revision. This happens without any human intervention.

### Manual Rollback via AWS CLI

*SHELL — Manual rollback procedure*

```
# 1. List recent task definition revisions
aws ecs list-task-definitions \
  --family-prefix my-api-staging-app \
  --sort DESC \
  --query 'taskDefinitionArns[:5]'

# Output example:
# [
#   "arn:aws:ecs:us-east-1:123456789:task-definition/my-api-staging-app:47",  ← current (broken)
#   "arn:aws:ecs:us-east-1:123456789:task-definition/my-api-staging-app:46",  ← previous (good)
#   "arn:aws:ecs:us-east-1:123456789:task-definition/my-api-staging-app:45",
# ]

# 2. Roll back to revision 46
aws ecs update-service \
  --cluster my-api-staging-cluster \
  --service my-api-staging-service \
  --task-definition my-api-staging-app:46 \
  --force-new-deployment

# 3. Watch the rollback progress
aws ecs describe-services \
  --cluster my-api-staging-cluster \
  --services my-api-staging-service \
  --query 'services[0].{running:runningCount,pending:pendingCount,desired:desiredCount,status:deployments[0].rolloutState}'
```

### Rollback GitHub Action

*YAML — .github/workflows/rollback.yml*

```
name: Rollback

on:
  workflow_dispatch:
    inputs:
      environment:
        description: Target environment
        required: true
        type: choice
        options: [staging, prod]
      revision:
        description: Task definition revision to roll back to (leave blank for previous)
        required: false
        type: string

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ inputs.environment == 'prod' && secrets.PROD_AWS_ROLE_ARN || secrets.STAGING_AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Get target revision
        id: revision
        run: |
          if [ -n "${{ inputs.revision }}" ]; then
            echo "arn=my-api-${{ inputs.environment }}-app:${{ inputs.revision }}" >> $GITHUB_OUTPUT
          else
            # Get the second-most-recent revision (one before current)
            PREV=$(aws ecs list-task-definitions \
              --family-prefix "my-api-${{ inputs.environment }}-app" \
              --sort DESC --query 'taskDefinitionArns[1]' --output text)
            echo "arn=$PREV" >> $GITHUB_OUTPUT
          fi

      - name: Execute rollback
        run: |
          echo "Rolling back to: ${{ steps.revision.outputs.arn }}"
          aws ecs update-service \
            --cluster "my-api-${{ inputs.environment }}-cluster" \
            --service "my-api-${{ inputs.environment }}-service" \
            --task-definition "${{ steps.revision.outputs.arn }}" \
            --force-new-deployment
          echo "✅ Rollback initiated"
```

### Zero-Downtime: How It Actually Works

ECS rolling deploys work as follows:

1. ECS starts a new task with the updated image
2. ALB health checks run against the new task — it must return 200 on `/health`
3. Once healthy, the new task is registered in the target group and starts receiving traffic
4. ECS sends SIGTERM to the old task — your server handles this and drains connections
5. After the deregistration delay (30s), the old task is fully stopped
6. ECS repeats for the next task until all tasks are updated

The **deregistration delay of 30 seconds** in the ALB target group matches the **15-second graceful shutdown timeout** in your Node.js server. This guarantees in-flight requests complete before the container exits.

#### 📌 Section Takeaways

- ECS Circuit Breaker auto-rollback is your first safety net — it requires zero manual action
- Keep the rollback workflow in GitHub Actions so anyone on the team can roll back, not just people with AWS CLI access
- Zero-downtime depends on your health check, deregistration delay, and SIGTERM handling all working together
- Test your rollback procedure during a calm period — not during an incident

Section 12

## Cost Controls & Cleanup

### Cost Breakdown: What This Stack Costs

| Resource | Dev/Month | Prod/Month (est.) |
| --- | --- | --- |
| ECS Fargate (512 CPU / 1GB, 1 task) | ~$15 | ~$45 (2 tasks, larger CPU) |
| NAT Gateway (1 AZ) | ~$32 | ~$64 (2 AZs) |
| ALB | ~$18 | ~$22 |
| RDS PostgreSQL (db.t4g.micro) | ~$15 | ~$50 (db.t4g.small, Multi-AZ) |
| ECR (10 images) | ~$1 | ~$2 |
| CloudWatch Logs | ~$2 | ~$10 |
| **Total estimate** | **~$83/mo** | **~$193/mo** |

### Cost Reduction Tips

*HCL — Fargate Spot for non-prod*

```
# Use FARGATE_SPOT for dev/staging to save ~70% on compute
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    # Prod: 100% FARGATE (no spot interruptions)
    # Dev: 0 FARGATE base, 100% SPOT
    capacity_provider = var.environment == "prod" ? "FARGATE" : "FARGATE_SPOT"
    weight            = 1
    base              = var.environment == "prod" ? 1 : 0
  }
}
```

### Teardown — Delete Everything

*SHELL — Full teardown*

```
# Scale ECS to 0 first (faster teardown)
aws ecs update-service \
  --cluster my-api-staging-cluster \
  --service my-api-staging-service \
  --desired-count 0

# Delete all ECR images (required before ECR destroy)
aws ecr batch-delete-image \
  --repository-name my-api-staging \
  --image-ids "$(aws ecr list-images \
    --repository-name my-api-staging \
    --query 'imageIds[*]' --output json)"

# Terraform destroy — removes all provisioned resources
cd terraform/
terraform destroy \
  -var-file=environments/staging.tfvars \
  -auto-approve
```

⚠️ Destroy Protection

Production resources have `enable_deletion_protection = true` on the ALB and should have similar protection on RDS. Terraform destroy will fail on these — you'll need to disable deletion protection manually first, or via Terraform with a targeted apply.

Section 13

## Troubleshooting Guide

Real issues you'll hit, and how to fix them fast.

### Issue: ECS Tasks Keep Restarting (Exit Code 1)

*SHELL — Debug ECS task failures*

```
# Find stopped tasks and their stop reasons
aws ecs describe-tasks \
  --cluster my-api-staging-cluster \
  --tasks $(aws ecs list-tasks \
    --cluster my-api-staging-cluster \
    --desired-status STOPPED \
    --query 'taskArns[:3]' --output text) \
  --query 'tasks[*].{status:lastStatus,stop:stoppedReason,containers:containers[*].{name:name,exit:exitCode,reason:reason}}'

# Check CloudWatch Logs for the stopped task
aws logs get-log-events \
  --log-group-name /ecs/my-api-staging \
  --log-stream-name "ecs/app/TASK_ID_HERE" \
  --limit 100
```

**Common causes:**

- Missing or wrong environment variable — check config fail-fast logic
- Database unreachable — check security group rules between ECS and RDS
- Node.js port conflict — ensure `PORT` env var matches `containerPort` in task def
- OOM killed — increase container memory or fix a memory leak

### Issue: ALB Returns 503 Service Unavailable

- Check that the target group shows healthy targets: `aws elbv2 describe-target-health --target-group-arn ...`
- Verify the health check path (`/health`) returns 200 from inside the container
- Check that ECS security group allows inbound on the container port from the ALB security group
- Look for `startPeriod` in the health check — give slow-starting apps time before marking unhealthy

### Issue: GitHub Actions OIDC Authentication Fails

- Verify the OIDC provider thumbprints are current (AWS occasionally rotates them)
- Check the `StringLike` condition in the IAM role — the subject must match `repo:org/repo:ref:refs/heads/main` exactly
- Ensure `id-token: write` permission is in the workflow's `permissions` block
- Verify the role ARN in `AWS_ROLE_ARN` secret has no leading/trailing whitespace

### Issue: Docker Image Pushed but ECS Still Running Old Version

- Check that the task definition was updated — the new image URI must be in the container definition
- Ensure `force-new-deployment: true` is set in the GitHub Actions ECS deploy step
- If you're using the `:latest` tag, ECS may cache it — always tag with the commit SHA and specify the full SHA-tagged URI in the task definition

### Issue: Terraform Wants to Destroy the ECS Service

This happens if you forgot `lifecycle { ignore_changes = [task_definition] }` on the ECS service. Terraform sees the task definition has been updated by GitHub Actions and wants to revert it. Add the lifecycle block and run `terraform apply` — it will add the ignore rule without affecting your running service.

#### 📌 Section Takeaways

- `aws ecs describe-tasks` on STOPPED tasks is your first stop for ECS debugging
- Always use SHA-tagged images in task definitions, not `:latest` — it makes rollbacks unambiguous
- OIDC failures are usually a mismatch in the IAM role's trust policy conditions — read them carefully
- The `lifecycle.ignore_changes` block on the ECS service is not optional

Section 14

## What's Next: Level Up Your Stack

This guide got you to a solid, production-ready foundation. Here's what to tackle next, in rough priority order:

### Immediate Next Steps

1. **HTTPS / TLS.** Add an ACM certificate and HTTPS listener to your ALB. Use `aws_acm_certificate` and `aws_acm_certificate_validation` in Terraform, and add a Route 53 record pointing to the ALB.
2. **ECS Auto Scaling.** Add `aws_appautoscaling_target` and `aws_appautoscaling_policy` resources to scale task count based on ALB request count or CPU utilization. Set min=2, max=10 for a typical API.
3. **WAF.** Attach AWS WAF to the ALB for rate limiting, bot detection, and OWASP top-10 protection. The managed rule groups are a great starting point.
4. **Database migrations.** Add a GitHub Actions step that runs migrations (e.g., `node scripts/migrate.js`) before deploying the new ECS tasks. Use ECS `run-task` to run the migration as a one-off task in the same network.

### Longer-Term Improvements

1. **Blue/Green deployments.** Switch from rolling to blue/green using AWS CodeDeploy + ECS. This gives you instant traffic switching and instant rollback with zero overlap period.
2. **OpenTelemetry.** Add the AWS Distro for OpenTelemetry (ADOT) as a sidecar container. Instrument your Node.js app with the OTEL SDK to get distributed traces in AWS X-Ray.
3. **Terraform remote state + locking.** If you haven't already, move Terraform state to an S3 bucket with DynamoDB locking. Add a backend.tf and run `terraform init -migrate-state`.
4. **Dependency scanning.** Add `npm audit` to the GitHub Actions test job. Consider adding `trivy` Docker image scanning before the ECR push step.
5. **Service mesh / ECS Service Connect.** When you have multiple services talking to each other, ECS Service Connect provides service discovery and observability without managing a full mesh.

✅ The Complete Repo

All code examples from this guide are organized into a working repository structure. Start by running `terraform apply` in a dev environment to validate your setup before touching staging or production.

The Big Picture

## The Complete Checklist

#### ✅ Infrastructure (Terraform)

- VPC with public + private subnets across 2+ AZs
- NAT Gateways for private subnet outbound access
- ALB with target group and HTTP listener
- ECR repository with image scanning and lifecycle policies
- ECS Fargate cluster with Container Insights enabled
- ECS task definition with health check and Secrets Manager integration
- ECS service with circuit breaker + auto-rollback
- IAM roles: task execution, task, and GitHub Actions OIDC
- Secrets Manager for sensitive config
- CloudWatch log group and key metric alarms
- S3 backend with DynamoDB state locking

#### ✅ Application (Node.js)

- `/health` (liveness) and `/ready` (readiness with DB check) endpoints
- SIGTERM handler for graceful shutdown
- Structured JSON logging (Pino)
- Fail-fast on missing required env vars in production
- Multi-stage Dockerfile with non-root user
- Comprehensive `.dockerignore`

#### ✅ CI/CD (GitHub Actions)

- PR checks: lint + test + Docker build (no push)
- Main branch: test → build → push to ECR → deploy to ECS
- OIDC for AWS authentication (no static keys)
- Docker layer caching via GitHub Actions cache
- Smoke test after deploy
- Manual rollback workflow
- Production deploy requires manual approval

7 Punchy Topics (≤25 chars)

🏗️

##### IaC or Go Home

#terraform #aws

🐳

##### Docker Done Right

#containers #devops

⚡

##### Push. Ship. Done.

#cicd #automation

🔐

##### Zero Static Keys

#oidc #security

🔄

##### Roll Back in 60s

#ecs #reliability

🌐

##### Fargate, Not K8s

#ecs #simplicity

💰

##### Infra on a Budget

#cost #efficiency

SEO Hashtags

Primary · Secondary · Tertiary

#NodeJS, #Terraform, #AWS, #GitHubActions, #DevOps, #CICD, #ECS, #Fargate, #InfrastructureAsCode, #CloudNative, #Docker, #ECR, #IAM, #OIDC, #CloudDevOps, #SoftwareDeployment, #AWSCloud, #BackendDevelopment, #ZeroDowntime, #ContainerOrchestration, #PlatformEngineering, #TerraformAWS, #NodeJsDeployment, #GitOps, #CloudSecurity, #SecretsManager, #Microservices, #SRE, #AutomatedDeployment, #AWSFargate

Ship It Right

Node.js → AWS · Terraform · GitHub Actions

Tagline

"Build once, ship anywhere, sleep at night — because your infrastructure writes the playbook, not you."
