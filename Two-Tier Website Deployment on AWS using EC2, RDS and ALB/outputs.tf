# ============================================================
#  outputs.tf
#
#  Printed in terminal after terraform apply.
#  Gives you everything you need to complete setup and test.
# ============================================================


output "step1_what_terraform_created" {
  value = <<-MSG

    ✅ TERRAFORM CREATED THESE AUTOMATICALLY:
    ─────────────────────────────────────────
    VPC              : TodoAppVPC (10.0.0.0/16)
    Public Subnets   : Public-A (us-east-1a), Public-B (us-east-1b)
    Private Subnets  : Private-A (us-east-1a), Private-B (us-east-1b)
    Internet Gateway : TodoApp-IGW
    Route Tables     : Public + Private
    Security Groups  : ALB-SG, Webserver-SG, Database-SG
    EC2 Instances    : BastionHost, web-server-1, web-server-2
    RDS MySQL        : ${aws_db_instance.todo_db.identifier}
    Load Balancer    : TodoApp-ALB
  MSG
}


output "step2_app_url" {
  description = "Open this URL in browser to see the Todo app"
  value       = <<-MSG

    🌐 YOUR TODO APP URL:
    ─────────────────────
    http://${aws_lb.todo_alb.dns_name}

    ⚠️  Wait 3-5 minutes after apply for:
    1. EC2 instances to finish setup (user_data script runs on boot)
    2. ALB health checks to pass
    3. RDS to become available
  MSG
}


output "step3_rds_details" {
  description = "RDS connection details (for connecting via Bastion Host)"
  value       = <<-MSG

    🗄️  RDS DATABASE DETAILS:
    ──────────────────────────
    Endpoint : ${aws_db_instance.todo_db.address}
    Port     : 3306
    Database : ${var.db_name}
    Username : ${var.db_username}
    Password : (set in variables.tf)

    ⚠️  RDS is in a PRIVATE subnet — not accessible from internet.
    To connect from your laptop, use the Bastion Host (see step 4).
  MSG
}


output "step4_bastion_host" {
  description = "How to connect to RDS via Bastion Host"
  value       = <<-MSG

    🔐 BASTION HOST (to connect to RDS):
    ──────────────────────────────────────
    Bastion Public IP: ${aws_instance.bastion_host.public_ip}

    1. SSH into bastion host:
       ssh -i bastion-host-key.pem ec2-user@${aws_instance.bastion_host.public_ip}

    2. Install MySQL client on bastion:
       sudo wget https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
       sudo dnf install mysql80-community-release-el9-1.noarch.rpm -y
       sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
       sudo dnf install mysql-community-client -y

    3. Connect to RDS from bastion:
       mysql -h ${aws_db_instance.todo_db.address} -P 3306 -u ${var.db_username} -p

    4. Create the database schema:
       CREATE DATABASE TodoAppDB;
       USE TodoAppDB;
       CREATE TABLE Tasks (
         id INT AUTO_INCREMENT PRIMARY KEY,
         task_name VARCHAR(255) NOT NULL,
         task_description TEXT,
         due_date DATE NULL,
         completed BOOLEAN DEFAULT FALSE
       );
  MSG
}


output "step5_web_servers" {
  description = "Individual EC2 web server IPs (for debugging)"
  value       = <<-MSG

    🖥️  WEB SERVERS:
    ─────────────────
    web-server-1 : http://${aws_instance.web_server_1.public_ip}
    web-server-2 : http://${aws_instance.web_server_2.public_ip}

    SSH into web-server-1:
    ssh -i ${var.key_pair_name}.pem ec2-user@${aws_instance.web_server_1.public_ip}

    Check app logs:
    pm2 logs

    Check Nginx status:
    sudo systemctl status nginx
  MSG
}


output "step6_troubleshooting" {
  value = <<-MSG

    🔧 TROUBLESHOOTING:
    ────────────────────
    ❌ App not loading after 5 mins?
       → SSH into web-server-1 and check:
         sudo cat /var/log/cloud-init-output.log
         pm2 status
         pm2 logs

    ❌ ALB showing unhealthy targets?
       → Wait 3-5 mins — health checks need time
       → Check Nginx is running: sudo systemctl status nginx

    ❌ Database connection error?
       → Schema not created yet! Run step 4 commands above
       → Check .env file: cat /home/ec2-user/Todo-Two-Tier/.env

    ❌ key_pair_name error in terraform plan?
       → Create the key pair first in EC2 Console
         EC2 → Key Pairs → Create key pair → name: bastion-host-key
       → Download the .pem file
  MSG
}
