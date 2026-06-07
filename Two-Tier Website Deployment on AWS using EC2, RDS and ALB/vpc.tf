# ============================================================
#  vpc.tf
#
#  VPC = Virtual Private Cloud
#  Think of it as YOUR private section of the AWS network.
#  Nothing can enter or leave unless you explicitly allow it.
#
#  WHAT WE BUILD HERE:
#
#  VPC (10.0.0.0/16)
#  ├── Public Subnet A  (10.0.1.0/24) → us-east-1a → EC2 web-server-1
#  ├── Public Subnet B  (10.0.3.0/24) → us-east-1b → EC2 web-server-2
#  ├── Private Subnet A (10.0.2.0/24) → us-east-1a → RDS primary
#  └── Private Subnet B (10.0.4.0/24) → us-east-1b → RDS standby
#
#  Internet Gateway → allows public subnets to reach internet
#  Public Route Table  → routes internet traffic through IGW
#  Private Route Table → no internet access (database safety)
# ============================================================


# ── STEP 1: VPC ───────────────────────────────────────────────
resource "aws_vpc" "todo_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  # enable_dns_hostnames = true is required for RDS to get
  # a proper hostname (endpoint) that EC2 can connect to

  tags = { Name = "TodoAppVPC", Project = "TodoApp" }
}


# ── STEP 2: Public Subnets ────────────────────────────────────
# "Public" = has a route to the internet via the IGW
# Web servers live here so users can reach them

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.todo_vpc.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  # map_public_ip_on_launch = EC2 instances here get a public IP automatically

  tags = { Name = "TodoApp-Subnet-Public-A", Project = "TodoApp" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.todo_vpc.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = { Name = "TodoApp-Subnet-Public-B", Project = "TodoApp" }
}


# ── STEP 3: Private Subnets ───────────────────────────────────
# "Private" = NO route to the internet
# RDS lives here — the database should NEVER be publicly accessible

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.todo_vpc.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = "${var.aws_region}a"

  tags = { Name = "TodoApp-Subnet-Private-A", Project = "TodoApp" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.todo_vpc.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = "${var.aws_region}b"

  tags = { Name = "TodoApp-Subnet-Private-B", Project = "TodoApp" }
}


# ── STEP 4: Internet Gateway ──────────────────────────────────
# The IGW is like the FRONT DOOR of your VPC to the internet.
# Without it, nothing in your VPC can communicate outside.

resource "aws_internet_gateway" "todo_igw" {
  vpc_id = aws_vpc.todo_vpc.id

  tags = { Name = "TodoApp-IGW", Project = "TodoApp" }
}


# ── STEP 5: Public Route Table ────────────────────────────────
# A route table is like a GPS — it tells traffic where to go.
# Public route table sends internet-bound traffic (0.0.0.0/0)
# through the Internet Gateway.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.todo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"           # all internet traffic
    gateway_id = aws_internet_gateway.todo_igw.id  # goes through IGW
  }

  tags = { Name = "TodoApp-Public-Route-Table", Project = "TodoApp" }
}

# Associate public subnets with the public route table
# This is what makes them "public" — they use the IGW route
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


# ── STEP 6: Private Route Table ───────────────────────────────
# Private route table has NO internet route.
# Private subnets (RDS) can only talk to other resources
# inside the VPC — not the public internet.

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.todo_vpc.id
  # No internet route here — intentional for security

  tags = { Name = "TodoApp-Private-Route-Table", Project = "TodoApp" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
