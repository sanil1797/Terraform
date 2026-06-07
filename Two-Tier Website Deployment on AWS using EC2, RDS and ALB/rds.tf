# ============================================================
#  rds.tf
#
#  RDS = Relational Database Service
#  It's a fully managed MySQL database — AWS handles backups,
#  patching, and hardware so you don't have to.
#
#  Our RDS instance lives in the PRIVATE subnets.
#  This means:
#    ✅ EC2 web servers (in public subnets) can connect to it
#    ❌ The public internet CANNOT connect to it directly
#
#  To connect to RDS from your laptop, you must first SSH
#  into the Bastion Host (EC2 in public subnet), then connect
#  from there — this is the secure way.
#
#  WHAT WE CREATE:
#    1. DB Subnet Group → tells RDS which subnets to use
#    2. RDS Instance    → the actual MySQL database
# ============================================================


# ── STEP 1: DB Subnet Group ───────────────────────────────────
# A subnet group is a collection of subnets that RDS can use.
# RDS requires at LEAST 2 subnets in different AZs
# (for high availability — if one AZ goes down, the other works)
resource "aws_db_subnet_group" "todo_db_subnet_group" {
  name        = "todo-db-subnet-group"
  description = "Private subnets for RDS MySQL"

  subnet_ids = [
    aws_subnet.private_a.id,   # us-east-1a
    aws_subnet.private_b.id,   # us-east-1b
  ]

  tags = { Name = "TodoApp-DB-Subnet-Group", Project = "TodoApp" }
}


# ── STEP 2: RDS MySQL Instance ────────────────────────────────
resource "aws_db_instance" "todo_db" {

  identifier = var.db_instance_identifier   # "todo-instance"

  # Database engine
  engine         = "mysql"
  engine_version = "8.0"

  # Instance size — db.t3.micro is free tier eligible
  instance_class = var.db_instance_class

  # Storage — 20GB is the minimum (free tier covers up to 20GB)
  allocated_storage = 20
  storage_type      = "gp2"

  # Database credentials
  db_name  = var.db_name       # creates "TodoAppDB" automatically
  username = var.db_username   # "admin"
  password = var.db_password   # from variables.tf

  # Networking — put RDS in private subnets
  db_subnet_group_name   = aws_db_subnet_group.todo_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_sg.id]

  # NO public access — database stays inside the VPC
  publicly_accessible = false

  # Free tier: no Multi-AZ (Multi-AZ = extra cost)
  multi_az = false

  # Skip final snapshot when deleting (for dev/testing)
  # Set to false in production to keep a backup when deleting
  skip_final_snapshot = true

  # Backup retention — 0 = disabled (saves cost for dev)
  backup_retention_period = 0

  tags = { Name = "TodoApp-DB", Project = "TodoApp" }
}
