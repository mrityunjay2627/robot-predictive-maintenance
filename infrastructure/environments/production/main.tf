# This is the main configuration file for our infrastructure.

# --- DATA SOURCE FOR UBUNTU AMI ---
# This block dynamically searches for the latest official Ubuntu 22.04 LTS AMI
# in the region we are deploying to. This is much more reliable than a hardcoded ID.
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Canonical's (the owner of Ubuntu) official AWS account ID
  owners = ["099720109477"]
}




module "vpc" {
  # This is the official, community-trusted blueprint for an AWS VPC.
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"

  # --- Basic VPC Details ---
  name = "robot-vpc"            # A name for our virtual network
  cidr = "10.0.0.0/16"           # The private IP address range for our entire network

  # --- Subnet Configuration ---
  # We want our network to span across 3 different physical datacenters (Availability Zones) for reliability.
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  
  # Define the IP ranges for our secure, private zones.
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  
  # Define the IP ranges for our public-facing zones.
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # --- Internet Access for Private Subnets ---
  # This creates a NAT Gateway, which acts as a secure, one-way door
  # for servers in our private subnets to access the internet (e.g., for software updates)
  # without allowing the internet to initiate connections back to them.
  enable_nat_gateway = true
  single_nat_gateway = true # Saves costs for this project
}

# --- SECURITY GROUPS (FIREWALL RULES) ---

# 1. A firewall for our public-facing Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH traffic from our user"
  vpc_id      = module.vpc.vpc_id # Place this firewall in our VPC

  # Inbound Rule: Who can connect to the server.
  ingress {
    from_port   = 22 # The port for SSH
    to_port     = 22
    protocol    = "tcp"
    # IMPORTANT: Replace this placeholder with your actual IP address.
    # This ensures only YOU can SSH into the bastion host.
    cidr_blocks = ["98.177.16.207/32"]
  }

  # Outbound Rule: Where the server can connect to.
  # We allow it to connect anywhere, which is standard.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # "-1" means all protocols
    cidr_blocks = ["0.0.0.0/0"] # "0.0.0.0/0" means anywhere on the internet
  }
}

# 2. A firewall for our private Kafka servers
resource "aws_security_group" "kafka_sg" {
  name        = "kafka-sg"
  description = "Allow traffic from bastion and between kafka nodes"
  vpc_id      = module.vpc.vpc_id

  # Inbound Rule 1: Allow all traffic from the Bastion Host.
  # Instead of an IP, we securely reference the bastion's security group ID.
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Inbound Rule 2: Allow Kafka servers to talk to each other.
  # This is required for them to form a cluster.
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true # 'self' means allow traffic from other servers in this same group
  }

  # Outbound Rule: Allow it to connect anywhere.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 INSTANCES (SERVERS) ---

# 1. The Bastion Host (our secure gateway)
resource "aws_instance" "bastion" {
  # Amazon Machine Image (AMI) is a template for the server's operating system.
  # We're using a standard Amazon Linux 2 AMI.
  ami                         = data.aws_ami.ubuntu.id
  
  # A t3.micro is a small, inexpensive server perfect for a bastion host.
  instance_type               = "t3.micro"
  
  # IMPORTANT: We place the bastion in our PUBLIC subnet.
  subnet_id                   = module.vpc.public_subnets[0]
  
  # Attach the bastion firewall rules we created earlier.
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  
  # This gives the bastion a public IP address so we can reach it from the internet.
  associate_public_ip_address = true
  
  # The name of the SSH key pair you have in your AWS account.
  # You need this to be able to log into the server.
  key_name                    = "robot-project-key" # <-- Replace with your key pair name
  
  tags = {
    Name = "bastion-host"
  }
}

# 2. The Kafka Broker Servers (our application servers)
resource "aws_instance" "kafka_broker" {
  # This creates 3 identical instances.
  count = 3

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium" # A bit larger to handle the Kafka workload
  
  # IMPORTANT: We place these servers in our PRIVATE subnets.
  # `count.index` places each of the 3 servers in a different private subnet for high availability.
  subnet_id     = module.vpc.private_subnets[count.index]

  # Attach the internal firewall rules we created earlier.
  vpc_security_group_ids = [aws_security_group.kafka_sg.id]

  key_name      = "robot-project-key" # <-- Replace with your key pair name
  
  tags = {
    Name = "kafka-broker-${count.index + 1}"
  }
}