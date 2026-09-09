# CI/CD with Terraform

A Spring Boot demo application with a full Jenkins CI/CD pipeline that builds, versions, containerizes, provisions AWS infrastructure with Terraform, and deploys the app to an EC2 instance via Docker Compose.

## Overview

On every pipeline run, Jenkins:

1. Runs the test suite.
2. Bumps the app's patch version in `pom.xml`.
3. Builds the Maven JAR.
4. Builds a Docker image tagged with the new version and pushes it to Docker Hub.
5. Provisions (or updates) AWS infrastructure with Terraform resources: VPC, subnet, internet gateway, security group, and an EC2 instance.
6. Copies `docker-compose.yaml` and `server-cmds.sh` to the EC2 instance and starts the app (and a Postgres container) via Docker Compose.
7. Commits the version bump back to the repository.

## Tech Stack

- **Application**: Java 17, Spring Boot 3.5.5 (Maven)
- **CI/CD**: Jenkins (Jenkinsfile using a [shared library](https://github.com/OyedunOye/jenkins-shared-library))
- **Containerization**: Docker, Docker Compose
- **Infrastructure**: Terraform, AWS (VPC, EC2, security groups)
- **Database**: PostgreSQL (via Docker Compose)

## Project Structure

```
.
├── Jenkinsfile              # Pipeline definition
├── Dockerfile                # Builds the app image (amazoncorretto:17-alpine-jdk)
├── docker-compose.yaml       # Runs the app + Postgres on the EC2 host
├── server-cmds.sh            # Remote script: docker login + docker-compose up
├── pom.xml                   # Maven build config
├── src/
│   └── main/
│       ├── java/com/example/Application.java   # Spring Boot entry point
│       └── resources/static/index.html
└── terraform/
    ├── main.tf                # VPC, subnet, IGW, security group, EC2 instance
    ├── variables.tf           # Input variables (region, CIDR blocks, IPs, instance type)
    ├── outputs.tf             # Exposes the EC2 public IP
    ├── providers.tf           # AWS provider requirement
    └── entry-script.sh        # EC2 user-data: installs Docker + docker-compose
```

## Prerequisites

- JDK 17 and Maven (for local builds)
- Docker and Docker Compose
- Terraform >= 1.x with the AWS provider `~> 6.0`
- AWS credentials with permission to manage VPC/EC2/security group resources
- An existing AWS key pair named `my-devops-ec2` (referenced in `terraform/main.tf`)
- A Jenkins instance with:
  - Maven tool configured as `maven-3.9`
  - Credentials: `d333e4b1-eb71-43bf-8485-7f068c14b823` (GitHub), `jenkins-aws-access-key-id` / `jenkins-secret-access-key` (AWS), `docker-credentials` (Docker Hub), `ec2-server-key` (SSH key for the EC2 instance)

## Local Development

Build and run the app locally:

```bash
mvn clean package
java -jar target/java-maven-app-*.jar
```

Or with Docker:

```bash
mvn clean package
docker build -t java-maven-app:local .
docker run -p 8080:8080 java-maven-app:local
```

The app starts on port `8080`.

## Infrastructure (Terraform)

`terraform/main.tf` provisions:

- A VPC (`10.0.0.0/16` by default) with one subnet and an internet gateway
- A default route table routing `0.0.0.0/0` through the IGW
- A default security group allowing inbound SSH (22) from `my_ip_address` / `jenkins_ip_address`, inbound `8080` from anywhere, and all outbound traffic
- An EC2 instance (latest Amazon Linux 2023 AMI, `t2.micro` by default) bootstrapped via `entry-script.sh`, which installs Docker and docker-compose

To provision manually:

```bash
cd terraform
terraform init
terraform apply
```

Key variables (see `terraform/variables.tf`) — override with `-var` or `TF_VAR_*` env vars as needed: `region`, `vpc_cidr_block`, `subnet_cidr_block`, `avail_zone`, `env_prefix`, `my_ip_address`, `jenkins_ip_address`, `instance_type`.

> **Note:** `my_ip_address` and `jenkins_ip_address` are hardcoded to specific IPs in `variables.tf` — update these to match your own environment before applying.

## CI/CD Pipeline (Jenkinsfile)

| Stage | Description |
|---|---|
| `test` | Runs the application test suite via the shared library's `testSourceCode()` |
| `increment version` | Bumps the incremental version in `pom.xml` and derives the Docker image tag `oluwasade/demo-app:jma-<version>-<build>` |
| `build app` | Builds the JAR via `buildJar()` |
| `build image` | Builds and pushes the Docker image to Docker Hub |
| `provision server` | Runs `terraform init` / `apply` in `terraform/` and captures the EC2 public IP |
| `deploy` | Waits for the EC2 instance to initialize, then copies `docker-compose.yaml` and `server-cmds.sh` over SSH and runs them to start the containers |
| `commit version update` | Commits and pushes the version bump back to `origin` |

## Deployment

On the EC2 instance, `server-cmds.sh` logs in to Docker Hub and runs:

```bash
docker-compose -f docker-compose.yaml up --detach
```

This starts two containers:
- `java-maven-app` — the Spring Boot app, exposed on port `8080`
- `postgres-db` — PostgreSQL, exposed on port `5432`


