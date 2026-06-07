# ============================================================
#  ec2.tf
#
#  3 EC2 instances:
#    1. Bastion Host  → SSH gateway to reach private RDS
#    2. Web Server 1  → Node.js app in public subnet A
#    3. Web Server 2  → Node.js app in public subnet B
#
#  user_data = startup script that auto-installs everything.
#  We use a separate .sh file (scripts/setup.sh) to avoid
#  heredoc-inside-heredoc conflicts in Terraform.
# ============================================================


# ── Get standard Amazon Linux 2023 AMI ───────────────────────
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


# ── Build the setup script with RDS/ALB values injected ──────
# templatefile() reads scripts/setup.sh and replaces
# ${db_host}, ${db_user} etc. with the real Terraform values.
# This avoids nested heredoc problems entirely.
locals {
  web_server_user_data = templatefile("${path.module}/scripts/setup.sh", {
    db_host  = aws_db_instance.todo_db.address
    db_user  = var.db_username
    db_pass  = var.db_password
    db_name  = var.db_name
    alb_dns  = aws_lb.todo_alb.dns_name
  })
}


# ── 1: Bastion Host ───────────────────────────────────────────
resource "aws_instance" "bastion_host" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  key_name               = var.key_pair_name

  tags = { Name = "BastionHost", Project = "TodoApp" }
}


# ── 2: Web Server 1 ───────────────────────────────────────────
resource "aws_instance" "web_server_1" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.webserver_sg.id]
  key_name                    = var.key_pair_name
  user_data                   = local.web_server_user_data
  user_data_replace_on_change = true

  tags = { Name = "web-server-1", Project = "TodoApp" }
}


# ── 3: Web Server 2 ───────────────────────────────────────────
resource "aws_instance" "web_server_2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_b.id
  vpc_security_group_ids      = [aws_security_group.webserver_sg.id]
  key_name                    = var.key_pair_name
  user_data                   = local.web_server_user_data
  user_data_replace_on_change = true

  tags = { Name = "web-server-2", Project = "TodoApp" }
}
