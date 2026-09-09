# CI/CD with Terraform and Remote State Configured

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
- `java-maven-app`: the Spring Boot app, exposed on port `8080`
- `postgres-db`: PostgreSQL, exposed on port `5432`

## Screenshots
![successful jenkin ci cd run](https://res.cloudinary.com/dpav6x91z/image/upload/v1788936877/Screenshot_2026-09-09_063853_hj1gwk.png)

![verified infra provisioned and app deployed](https://res.cloudinary.com/dpav6x91z/image/upload/v1788936906/Screenshot_2026-09-09_070643_m7om2p.png)

![access deployed app in browser](https://res.cloudinary.com/dpav6x91z/image/upload/v1788936939/Screenshot_2026-09-09_070525_w08lus.png)

## Remote Backend
To access the current state and track changes made to resources created by terraform, a remote state is set up in `/terraform/main.tf`. The remote storage chosen for this project is aws s3 bucket. This is done in 2 simple steps:
- In terraform block at the beginning of main.tf, configure a remote backend of choice.
- Create a remote storage for the chosen remote backend provider (aws s3 bucket in my case)
Commit and push changes to trigger ci/cd pipeline and then from the terminal when in the directory with the terraform configuration files, initialize the backend by running the command:
```bash
terraform init
```
- After initializing backend, access state using terraform command from the terminal. For instance:
```bash
terraform state list
```

![pipeline success](https://res.cloudinary.com/dpav6x91z/image/upload/v1788939563/Screenshot_2026-09-09_093815_qmsjqs.png)
![access remote state from local terminal](https://res.cloudinary.com/dpav6x91z/image/upload/v1788938509/Screenshot_2026-09-09_092119_xntm8n.png)
![ssh into ec2 instance from browser](https://res.cloudinary.com/dpav6x91z/image/upload/v1788940185/Screenshot_2026-09-09_094759_xspd9f.png)
![access deployed app in browser](https://res.cloudinary.com/dpav6x91z/image/upload/v1788940188/Screenshot_2026-09-09_094913_sopoqn.png)
**Note:** Other terraform commands are also accessible locally and they use the remote state for performing their functions.
