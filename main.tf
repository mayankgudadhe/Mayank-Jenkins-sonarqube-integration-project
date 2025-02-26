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
  alias  = "mumbai"
}

# DR Region Provider (North Virginia)
provider "aws" {
  region = "us-east-1"  # DR region (North Virginia)
  alias  = "dr_region"
}

# --- Mumbai VPC and Resources ---
resource "aws_vpc" "mumbai_vpc" {
  provider = aws.mumbai
  cidr_block = "10.10.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "Mumbai-VPC"
  }
}

resource "aws_subnet" "mumbai_public_subnet" {
  provider = aws.mumbai
  vpc_id     = aws_vpc.mumbai_vpc.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Mumbai-Public-Subnet"
  }
}

resource "aws_subnet" "mumbai_private_subnet" {
  provider = aws.mumbai
  vpc_id     = aws_vpc.mumbai_vpc.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "Mumbai-Private-Subnet"
  }
}

resource "aws_internet_gateway" "mumbai_igw" {
  provider = aws.mumbai
  vpc_id = aws_vpc.mumbai_vpc.id
  tags = {
    Name = "Mumbai-Internet-Gateway"
  }
}

resource "aws_eip" "mumbai_nat_eip" {
  provider = aws.mumbai
  vpc = true
}

resource "aws_nat_gateway" "mumbai_nat_gw" {
  provider = aws.mumbai
  allocation_id = aws_eip.mumbai_nat_eip.id
  subnet_id     = aws_subnet.mumbai_public_subnet.id
  tags = {
    Name = "Mumbai-NAT-Gateway"
  }
}

resource "aws_route_table" "mumbai_public_route_table" {
  provider = aws.mumbai
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
  provider      = aws.mumbai
  subnet_id      = aws_subnet.mumbai_public_subnet.id
  route_table_id = aws_route_table.mumbai_public_route_table.id
}

resource "aws_route_table" "mumbai_private_route_table" {
  provider = aws.mumbai
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
  provider      = aws.mumbai
  subnet_id      = aws_subnet.mumbai_private_subnet.id
  route_table_id = aws_route_table.mumbai_private_route_table.id
}

# Mumbai Custom Security Group
resource "aws_security_group" "mumbai_sg" {
  provider = aws.mumbai
  name        = "mumbai-sg"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.mumbai_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Use pre-generated SSH key in Mumbai region
resource "aws_instance" "mumbai_instance" {
  provider = aws.mumbai
  count = 3
  ami           = "ami-00bb6a80f01f03502"  # Provided Ubuntu AMI ID
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.mumbai_public_subnet.id  # Public subnet in Mumbai
  key_name      = "PR_REGION"  # Use the pre-generated key file "PR_REGION.pem"
  security_group_ids = [aws_security_group.mumbai_sg.name]

  associate_public_ip_address = true

  tags = {
    Name = "Mumbai-EC2-${count.index + 1}"
  }
  depends_on = [aws_security_group.mumbai_sg]
}

# --- DR Region Resources ---
resource "aws_vpc" "dr_vpc" {
  provider = aws.dr_region
  cidr_block = "10.20.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "DR-VPC"
  }
}

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

resource "aws_subnet" "dr_private_subnet" {
  provider = aws.dr_region
  vpc_id     = aws_vpc.dr_vpc.id
  cidr_block = "10.20.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "DR-Private-Subnet"
  }
}

resource "aws_internet_gateway" "dr_igw" {
  provider = aws.dr_region
  vpc_id = aws_vpc.dr_vpc.id
  tags = {
    Name = "DR-Internet-Gateway"
  }
}

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

# DR Custom Security Group
resource "aws_security_group" "dr_sg" {
  provider = aws.dr_region
  name        = "dr-sg"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.dr_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Use pre-generated SSH key in DR region
resource "aws_instance" "dr_instance" {
  provider = aws.dr_region
  count = 3
  ami           = "ami-04b4f1a9cf54c11d0"  # Same Ubuntu AMI ID for DR region
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.dr_public_subnet.id  # Public subnet in DR region
  key_name      = "DR_REGION"  # Use the pre-generated key file "DR_REGION.pem"
  security_group_ids = [aws_security_group.dr_sg.name]

  associate_public_ip_address = true

  tags = {
    Name = "DR-EC2-${count.index + 1}"
  }
  depends_on = [aws_security_group.dr_sg]
}

# VPC Peering between Mumbai and DR VPC
resource "aws_vpc_peering_connection" "vpc_peering" {
  provider    = aws.mumbai
  vpc_id      = aws_vpc.mumbai_vpc.id
  peer_vpc_id = aws_vpc.dr_vpc.id
  peer_region = "us-east-1"  # DR region
  auto_accept = false  # Disable auto-accept, as it cannot be used with peer_region

  tags = {
    Name = "Mumbai-to-DR-VPC-Peering"
  }
}

# Accept the VPC Peering Connection on DR Region (Peer VPC)
resource "aws_vpc_peering_connection_accepter" "dr_vpc_peering_accepter" {
  provider                  = aws.dr_region
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
  auto_accept               = true  # Automatically accept on the DR side

  tags = {
    Name = "DR-to-Mumbai-VPC-Peering"
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
