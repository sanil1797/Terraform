# ✅ Two-Tier Todo App on AWS using Terraform

A real-world cloud deployment of a Todo List web application on AWS.
Built using a **two-tier architecture** — web servers in one layer, database in another.
Everything is created automatically using **Terraform** — no manual clicking in the AWS Console.

---

## 🤔 What is Two-Tier Architecture?

Think of it like a restaurant:

```
Customer (you)
    ↓
Waiter (Web Server / EC2)     ← takes your order, serves your food
    ↓
Kitchen (Database / RDS)      ← stores and prepares everything
```

- **Tier 1 (Application Layer)** — EC2 instances run the Node.js web app that users see
- **Tier 2 (Database Layer)** — RDS MySQL stores all the tasks permanently

They are kept **separate** for security and scalability.

---

## 🏗️ Architecture Diagram

```
                    INTERNET
                       │
                       ▼
           ┌─────────────────────┐
           │  Application Load   │  ← single URL for users
           │  Balancer (ALB)     │  ← distributes traffic evenly
           └──────────┬──────────┘
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
   ┌─────────────┐         ┌─────────────┐
   │ Web Server 1│         │ Web Server 2│
   │  (us-east-1a)│        │ (us-east-1b)│  ← 2 servers, 2 zones
   │  Node.js app│         │  Node.js app│  ← if one fails, other works
   └──────┬──────┘         └──────┬──────┘
          │                       │
          └───────────┬───────────┘
                      ▼
           ┌─────────────────────┐
           │    RDS MySQL        │  ← private, not on internet
           │  (TodoAppDB)        │  ← stores all tasks permanently
           └─────────────────────┘

           ┌─────────────────────┐
           │    Bastion Host     │  ← jump server to access RDS
           │  (public subnet)    │  ← SSH here first, then to RDS
           └─────────────────────┘
```

---

## ☁️ AWS Services Used

| Service | What it does | Like... |
|---|---|---|
| **VPC** | Your private network on AWS | Your own office building |
| **Subnets** | Sections inside the VPC | Floors in the building |
| **Internet Gateway** | Connects VPC to internet | The building's front door |
| **Security Groups** | Controls who can talk to what | Security guards |
| **EC2** | Virtual servers running the Node.js app | The waiters |
| **RDS MySQL** | Managed database storing tasks | The kitchen/storage |
| **ALB** | Distributes traffic between EC2s | The receptionist |
| **Bastion Host** | Jump server to access private RDS | A back-door access pass |
| **IAM** | Permissions and security | ID badges |

---

## 📁 Project Structure

```
todo-app/
├── main.tf              # Terraform setup + AWS provider
├── variables.tf         # All settings (region, passwords, names)
├── vpc.tf               # VPC, subnets, internet gateway, route tables
├── security_groups.tf   # Firewall rules for ALB, EC2, and RDS
├── rds.tf               # MySQL database in private subnets
├── ec2.tf               # 3 EC2 instances + startup script
├── alb.tf               # Load balancer + target group + listener
├── outputs.tf           # Prints app URL + next steps after deploy
├── .gitignore           # Stops sensitive files going to GitHub
└── scripts/
    └── setup.sh         # Auto-install script (Node.js, app, Nginx)
```

---

## 🔒 Security Design

```
Internet → ALB (port 80 open)
              ↓
         EC2 (only accepts traffic FROM ALB)
              ↓
         RDS (only accepts traffic FROM EC2)
              ↑
         NOT accessible from internet at all
```

Each layer only talks to the layer next to it:
- Users → ALB only
- ALB → EC2 only
- EC2 → RDS only
- RDS → not reachable from outside

---

## 🌐 Networking (VPC) Explained

```
VPC: 10.0.0.0/16  (your private network)
│
├── Public Subnet A  (10.0.1.0/24) → us-east-1a
│   └── Web Server 1 + Bastion Host
│
├── Public Subnet B  (10.0.3.0/24) → us-east-1b
│   └── Web Server 2
│
├── Private Subnet A (10.0.2.0/24) → us-east-1a
│   └── RDS Primary
│
└── Private Subnet B (10.0.4.0/24) → us-east-1b
    └── RDS Standby
```

**Public subnets** have a route to the internet (via Internet Gateway).
**Private subnets** have NO internet route — database is completely hidden.

---

## 🚀 How to Deploy

### Before you start

1. Install [Terraform](https://developer.hashicorp.com/terraform/downloads)
2. Install [AWS CLI](https://aws.amazon.com/cli/) and configure it:
   ```bash
   aws configure
   # Enter your Access Key, Secret Key, region: us-east-1
   ```
3. Create an EC2 Key Pair:
   - AWS Console → EC2 → Key Pairs → Create key pair
   - Name: `bastion-host-key`
   - Download the `.pem` file — keep it safe!

### Deploy

```bash
# 1. Download providers
terraform init

# 2. Preview what will be created
terraform plan

# 3. Create everything (type 'yes' when asked)
terraform apply
```

Terraform creates **25 AWS resources** automatically in about 10 minutes.

---

## 📋 After Deployment — Manual Steps

After `terraform apply` finishes, the outputs print everything you need.

### Step 1 — Create the database table

SSH into the bastion host:
```bash
ssh -i "bastion-host-key.pem" ec2-user@BASTION_IP
```

Install MySQL client:
```bash
sudo dnf install -y mariadb105
```

Connect to RDS:
```bash
mysql -h YOUR_RDS_ENDPOINT -P 3306 -u admin -p
# Password: TodoApp2026! (or whatever you set in variables.tf)
```

Create the table:
```sql
USE TodoAppDB;

CREATE TABLE Tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  task_name VARCHAR(255) NOT NULL,
  task_description TEXT,
  due_date DATE NULL,
  completed BOOLEAN DEFAULT FALSE
);

exit;
```

### Step 2 — Open the app

Copy the ALB URL from the terraform output and open it in your browser:
```
http://TodoApp-ALB-XXXXXXXXXX.us-east-1.elb.amazonaws.com
```

Wait 3-5 minutes after deploy for the web servers to finish setting up.

---

## 🔄 How It Works (Full Flow)

```
1. You open the ALB URL in browser

2. ALB receives request
   → checks which web server is healthy
   → forwards to web-server-1 OR web-server-2

3. Node.js app on EC2 handles request

4. App connects to RDS MySQL
   → reads existing tasks
   → saves new tasks

5. Response sent back through ALB to your browser

6. Tasks appear on screen ✅
```

When you add a task:
```
You click "Add Task"
    → Node.js sends INSERT to MySQL
    → MySQL stores it permanently
    → Page refreshes, task appears
    → Even after refresh it stays (it's in the database!)
```

---

## 🧪 Troubleshooting

| Problem | Fix |
|---|---|
| 502 Bad Gateway | Wait 5 mins — app is still installing on EC2 |
| Task resets on submit | Create the Tasks table (see manual steps above) |
| Can't SSH into bastion | Check .pem file path and permissions |
| Can't connect to RDS | Make sure you're SSHed into bastion first |
| App URL not working | Check ALB health checks in AWS Console |

### Check app logs on web server
```bash
ssh -i "bastion-host-key.pem" ec2-user@WEB_SERVER_IP
pm2 logs --lines 50
sudo systemctl status nginx
```

### Check setup log
```bash
sudo cat /var/log/user-data.log
```

---

## 💰 Cost

| Resource | Free Tier? |
|---|---|
| EC2 t2.micro (x3) | ✅ 750 hrs/month free |
| RDS db.t3.micro | ✅ 750 hrs/month free |
| ALB | ⚠️ ~$0.008/hour (~$5-6/month) |
| Data transfer | ✅ Minimal for testing |

**Destroy when done to avoid charges:**
```bash
terraform destroy
```

---

## 🗑️ Cleanup

```bash
terraform destroy
```

This deletes all 25 resources — EC2, RDS, ALB, VPC, subnets, security groups, everything. Type `yes` when prompted.

> Note: RDS may take 5-10 minutes to fully delete.

---

## 📚 What You Learned

- ✅ How to design a two-tier cloud architecture
- ✅ VPC networking — subnets, route tables, internet gateway
- ✅ Security groups as layered firewalls
- ✅ RDS — managed database in private subnets
- ✅ EC2 with auto-setup scripts (user_data)
- ✅ Application Load Balancer for high availability
- ✅ Bastion host pattern for secure database access
- ✅ Infrastructure as Code with Terraform

