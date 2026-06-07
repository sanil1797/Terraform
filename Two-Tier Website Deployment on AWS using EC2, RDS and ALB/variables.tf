# ============================================================
#  variables.tf
#
#  All settings in one place.
#  Change the "default" values here — no other file needed.
#
#  ⚠️  IMPORTANT: Change db_password to something strong!
# ============================================================


variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}


# ── VPC ───────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "IP range for the VPC (covers all subnets)"
  type        = string
  default     = "10.0.0.0/16"
  # /16 = 65,536 IP addresses — more than enough
}


# ── Subnets ───────────────────────────────────────────────────
# Public subnets — for EC2 (web servers) and ALB
# Private subnets — for RDS (database, not internet-accessible)

variable "public_subnet_a_cidr" {
  description = "Public subnet in us-east-1a (web-server-1 lives here)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "Public subnet in us-east-1b (web-server-2 lives here)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_a_cidr" {
  description = "Private subnet in us-east-1a (RDS lives here)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_b_cidr" {
  description = "Private subnet in us-east-1b (RDS standby lives here)"
  type        = string
  default     = "10.0.4.0/24"
}


# ── EC2 ───────────────────────────────────────────────────────
variable "instance_type" {
  description = "EC2 instance type (t2.micro = free tier)"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
  default     = "bastion-host-key"
  # Create this in EC2 Console → Key Pairs → Create key pair
  # Download the .pem file — you need it to SSH in
}


# ── RDS ───────────────────────────────────────────────────────
variable "db_instance_identifier" {
  description = "Unique name for the RDS MySQL instance"
  type        = string
  default     = "todo-instance"
}

variable "db_name" {
  description = "Name of the database inside RDS"
  type        = string
  default     = "TodoAppDB"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for RDS — change this!"
  type        = string
  default     = "TodoApp2026!"   # ← change to something strong
  sensitive   = true             # hides the value in terminal output
}

variable "db_instance_class" {
  description = "RDS instance size (db.t3.micro = free tier)"
  type        = string
  default     = "db.t3.micro"
}
