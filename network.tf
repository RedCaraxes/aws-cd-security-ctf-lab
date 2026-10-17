data "aws_ec2_instance_type_offerings" "lab" {
  provider      = aws.a
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

resource "aws_vpc" "lab" {
  provider             = aws.a
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "org-security-lab-vpc"
  }
}

resource "aws_internet_gateway" "lab" {
  provider = aws.a
  vpc_id   = aws_vpc.lab.id

  tags = {
    Name = "org-security-lab-igw"
  }
}

resource "aws_subnet" "public" {
  provider                = aws.a
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.50.1.0/24"
  availability_zone       = try(sort(data.aws_ec2_instance_type_offerings.lab.locations)[0], null)
  map_public_ip_on_launch = true

  lifecycle {
    precondition {
      condition     = length(data.aws_ec2_instance_type_offerings.lab.locations) > 0
      error_message = "The configured instance_type is not offered in an Availability Zone in this region."
    }
  }

  tags = {
    Name = "org-security-lab-public"
  }
}

resource "aws_route_table" "public" {
  provider = aws.a
  vpc_id   = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "org-security-lab-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  provider       = aws.a
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ssrf_app" {
  provider    = aws.a
  name        = "org-security-lab-ssrf-app"
  description = "Intentionally vulnerable SSRF application - restricted to presenter CIDR"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "Demo HTTP endpoint"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.app_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "org-security-lab-ssrf-app"
  }
}

resource "aws_security_group" "jenkins" {
  provider    = aws.a
  name        = "org-security-lab-jenkins"
  description = "Legacy Jenkins node - no inbound network access; managed through SSM"
  vpc_id      = aws_vpc.lab.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "org-security-lab-jenkins"
  }
}
