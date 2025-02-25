terraform {
  backend "s3" {
    bucket = "sonarcube-backend-bucket"        # Replace with your S3 bucket name
    key    = "terraform/state.tfstate"         # Path within the bucket to store the state file
    region = "ap-south-1"                      # Your desired region for S3
    encrypt = true                             # Enable encryption for state file
    acl     = "bucket-owner-full-control"      # Set permissions for the state file
  }
}

# Mumbai Region Provider
provider "aws" {
  region = "ap-south-1"  # Mumbai region
}

# Create VPC in Mumbai
resource "aws_vpc" "mumbai_vpc" {
  cidr_block = "10.10.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "Mumbai-VPC"
  }
}

# Create Public Subnet in Mumbai
resource "aws_subnet" "mumbai_public_subnet" {
  vpc_id     = aws_vpc.mumbai_vpc.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Mumbai-Public-Subnet"
  }
}

# Create Private Subnet in Mumbai
resource "aws_subnet" "mumbai_private_subnet" {
  vpc_id     = aws_vpc.mumbai_vpc.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "Mumbai-Private-Subnet"
  }
}

# Create Internet Gateway for Mumbai
resource "aws_internet_gateway" "mumbai_igw" {
  vpc_id = aws_vpc.mumbai_vpc.id
  tags = {
    Name = "Mumbai-Internet-Gateway"
  }
}

# Create NAT Gateway for Mumbai
resource "aws_eip" "mumbai_nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "mumbai_nat_gw" {
  allocation_id = aws_eip.mumbai_nat_eip.id
  subnet_id     = aws_subnet.mumbai_public_subnet.id
  tags = {
    Name = "Mumbai-NAT-Gateway"
  }
}

# Create Route Table for Public Subnet in Mumbai
resource "aws_route_table" "mumbai_public_route_table" {
  vpc_id = aws_vpc.mumbai_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mumbai_igw.id
  }
  tags = {
    Name = "Mumbai-Public-Route-Table"
  }
}

resource "aws_route_table_association" "mumbai_public_route_association" {
  subnet_id      = aws_subnet.mumbai_public_subnet.id
  route_table_id = aws_route_table.mumbai_public_route_table.id
}

# Create Route Table for Private Subnet in Mumbai (Using NAT Gateway)
resource "aws_route_table" "mumbai_private_route_table" {
  vpc_id = aws_vpc.mumbai_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mumbai_nat_gw.id
  }
  tags = {
    Name = "Mumbai-Private-Route-Table"
  }
}

resource "aws_route_table_association" "mumbai_private_route_association" {
  subnet_id      = aws_subnet.mumbai_private_subnet.id
  route_table_id = aws_route_table.mumbai_private_route_table.id
}

# Create SSH Key Pair for Mumbai Region
resource "aws_key_pair" "mumbai_github_key" {
  key_name   = "mumbai-github-key"
  public_key = file("~/.ssh/github-ec2-key.pub")  # Ensure the public key is generated locally
}

# Launch EC2 instances in Mumbai
resource "aws_instance" "mumbai_instance" {
  count = 3
  ami           = "ami-00bb6a80f01f03502"  # Provided Ubuntu AMI ID
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.mumbai_public_subnet.id  # Public subnet in Mumbai
  key_name = aws_key_pair.mumbai_github_key.key_name  # Use generated SSH key pair

  associate_public_ip_address = true

  tags = {
    Name = "Mumbai-EC2-${count.index + 1}"
  }
}

# DR Region Provider (North Virginia)
provider "aws" {
  alias  = "dr_region"
  region = "us-east-1"  # DR region (North Virginia)
}

# Create VPC in DR Region
resource "aws_vpc" "dr_vpc" {
  provider = aws.dr_region
  cidr_block = "10.20.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "DR-VPC"
  }
}

# Create Public Subnet in DR Region
resource "aws_subnet" "dr_public_subnet" {
  provider = aws.dr_region
  vpc_id     = aws_vpc.dr_vpc.id
  cidr_block = "10.20.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "DR-Public-Subnet"
  }
}

# Create Private Subnet in DR Region
resource "aws_subnet" "dr_private_subnet" {
  provider = aws.dr_region
  vpc_id     = aws_vpc.dr_vpc.id
  cidr_block = "10.20.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "DR-Private-Subnet"
  }
}

# Create Internet Gateway for DR Region
resource "aws_internet_gateway" "dr_igw" {
  provider = aws.dr_region
  vpc_id = aws_vpc.dr_vpc.id
  tags = {
    Name = "DR-Internet-Gateway"
  }
}

# Create NAT Gateway for DR Region
resource "aws_eip" "dr_nat_eip" {
  provider = aws.dr_region
  vpc = true
}

resource "aws_nat_gateway" "dr_nat_gw" {
  provider = aws.dr_region
  allocation_id = aws_eip.dr_nat_eip.id
  subnet_id     = aws_subnet.dr_public_subnet.id
  tags = {
    Name = "DR-NAT-Gateway"
  }
}

# Create Route Table for Public Subnet in DR Region
resource "aws_route_table" "dr_public_route_table" {
  provider = aws.dr_region
  vpc_id = aws_vpc.dr_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr_igw.id
  }
  tags = {
    Name = "DR-Public-Route-Table"
  }
}

resource "aws_route_table_association" "dr_public_route_association" {
  provider      = aws.dr_region
  subnet_id      = aws_subnet.dr_public_subnet.id
  route_table_id = aws_route_table.dr_public_route_table.id
}

# Create Route Table for Private Subnet in DR Region (Using NAT Gateway)
resource "aws_route_table" "dr_private_route_table" {
  provider = aws.dr_region
  vpc_id = aws_vpc.dr_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dr_nat_gw.id
  }
  tags = {
    Name = "DR-Private-Route-Table"
  }
}

resource "aws_route_table_association" "dr_private_route_association" {
  provider      = aws.dr_region
  subnet_id      = aws_subnet.dr_private_subnet.id
  route_table_id = aws_route_table.dr_private_route_table.id
}

# Create SSH Key Pair for DR Region
resource "aws_key_pair" "dr_github_key" {
  provider = aws.dr_region
  key_name   = "dr-github-key"
  public_key = file("~/.ssh/github-ec2-key.pub")  # Ensure the public key is generated locally
}

# Launch EC2 instances in DR region
resource "aws_instance" "dr_instance" {
  provider = aws.dr_region
  count = 3
  ami           = "ami-00bb6a80f01f03502"  # Same Ubuntu AMI ID for DR region
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.dr_public_subnet.id  # Public subnet in DR region
  key_name = aws_key_pair.dr_github_key.key_name  # Use the SSH key pair from DR

  associate_public_ip_address = true

  tags = {
    Name = "DR-EC2-${count.index + 1}"
  }
}

# VPC Peering between Mumbai and DR VPC
resource "aws_vpc_peering_connection" "vpc_peering" {
  provider    = aws.dr_region
  vpc_id      = aws_vpc.mumbai_vpc.id
  peer_vpc_id = aws_vpc.dr_vpc.id
  peer_region = "us-east-1"  # DR region
  auto_accept = true

  tags = {
    Name = "Mumbai-to-DR-VPC-Peering"
  }
}

# Routes for peering between Mumbai and DR VPCs
resource "aws_route" "route_to_dr" {
  provider = aws.mumbai
  route_table_id         = aws_route_table.mumbai_public_route_table.id
  destination_cidr_block = "10.20.0.0/16"  # DR VPC CIDR
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

resource "aws_route" "route_to_mumbai" {
  provider = aws.dr_region
  route_table_id         = aws_route_table.dr_public_route_table.id
  destination_cidr_block = "10.10.0.0/16"  # Mumbai VPC CIDR
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}
