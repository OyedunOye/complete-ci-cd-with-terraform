# region, access_key and secret_key were configured in ~/.aws/credentials file
provider "aws" {
    region = var.region
}

resource "aws_vpc" "my-app-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

# creates subnet in newly created vpc. vpc and subnet are being created in the same plan. This apply command also generates a route table
resource "aws_subnet" "my-app-subnet-1" {
    vpc_id            = aws_vpc.my-app-vpc.id
    cidr_block        = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

# creates an internet gateway that is associated to the external route in default created route table
resource "aws_internet_gateway" "my-app-igw" {
    vpc_id = aws_vpc.my-app-vpc.id
    tags = {
        Name: "${var.env_prefix}-igw"
  }
}

# instead of creating another route table, use the default created on vpc creation and add igw to it
resource "aws_default_route_table" "main-rtb" {
    default_route_table_id = aws_vpc.my-app-vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my-app-igw.id
    }

    tags = {
        Name: "${var.env_prefix}-main-rtb"
    }
}

# this is where incoming (ingress) and outgoing (egress) traffic via ports are defined for server instance level. This modifies the default sg in the current vpc
resource "aws_default_security_group" "default-sg" {
    vpc_id = aws_vpc.my-app-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "TCP"
        cidr_blocks = [var.my_ip_address, var.jenkins_ip_address]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env_prefix}-default-sg"
    }
}

data "aws_ami" "latest-amazon-linux-image" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["al2023-ami-2023*x86_64"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}


resource "aws_instance" "my-app-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type
    subnet_id = aws_subnet.my-app-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = "my-devops-ec2"

    user_data = file("entry-script.sh")

    user_data_replace_on_change = true

    tags = {
        Name: "${var.env_prefix}-server"
    }
}
