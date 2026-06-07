# ============================================================
#  security_groups.tf
#
#  Security Groups = firewalls for your AWS resources.
#  They control what traffic is ALLOWED IN (inbound)
#  and what traffic can go OUT (outbound).
#
#  We create 3 security groups:
#
#  1. ALB-SG        → for the Load Balancer
#     Allows: HTTP (80) from anywhere (public internet)
#
#  2. Webserver-SG  → for EC2 instances
#     Allows: HTTP (80) from ALB only
#             SSH  (22) from anywhere (for admin access)
#             MySQL(3306) from anywhere (for DB connection)
#
#  3. Database-SG   → for RDS MySQL
#     Allows: MySQL (3306) from Webserver-SG only
#     (database only talks to web servers — not internet)
#
#  SECURITY CHAIN:
#  Internet → ALB-SG → Webserver-SG → Database-SG
# ============================================================


# ── 1: ALB Security Group ─────────────────────────────────────
# The Load Balancer faces the internet — accepts HTTP from anyone
resource "aws_security_group" "alb_sg" {
  name        = "ALB-SG"
  description = "Allow HTTP traffic from internet to ALB"
  vpc_id      = aws_vpc.todo_vpc.id

  # Allow HTTP (port 80) from anywhere on the internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # 0.0.0.0/0 = everyone
  }

  # Allow all outbound traffic (ALB needs to forward to EC2)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"            # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ALB-SG", Project = "TodoApp" }
}


# ── 2: Web Server Security Group ──────────────────────────────
# EC2 instances only accept HTTP from the ALB (not directly)
# This ensures all traffic goes through the load balancer
resource "aws_security_group" "webserver_sg" {
  name        = "Webserver-SG"
  description = "Allow traffic from ALB and SSH for admin"
  vpc_id      = aws_vpc.todo_vpc.id

  # Allow HTTP only from the ALB (not from the public internet directly)
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    # security_groups = only traffic from ALB is allowed
  }

  # Allow SSH from anywhere (so you can connect to debug)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow MySQL port (for connecting to RDS)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound (EC2 needs to call RDS, npm install, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Webserver-SG", Project = "TodoApp" }
}


# ── 3: Database Security Group ────────────────────────────────
# RDS only accepts MySQL connections from the web servers
# The database is NOT accessible from the internet at all
resource "aws_security_group" "database_sg" {
  name        = "TodoApp-Database-SG"
  description = "Allow MySQL only from web servers"
  vpc_id      = aws_vpc.todo_vpc.id

  # Only allow MySQL (3306) from EC2 web servers
  # The source is the Webserver-SG — not an IP address
  # This means: "only allow traffic from resources that
  # have the Webserver-SG attached"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver_sg.id]
  }

  # Allow outbound (RDS needs to respond to queries)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "TodoApp-Database-SG", Project = "TodoApp" }
}
