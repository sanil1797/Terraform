# ============================================================
#  alb.tf
#
#  ALB = Application Load Balancer
#  It sits in front of your two EC2 web servers and
#  distributes incoming requests between them.
#
#  WHY DO WE NEED AN ALB?
#    - If one EC2 instance crashes, all traffic goes to the other
#    - Distributes load so one server isn't overwhelmed
#    - Single URL for users — they don't need to know
#      about individual server IPs
#
#  HOW IT WORKS:
#    User → ALB DNS name
#           → ALB checks which EC2 is healthy
#           → forwards request to web-server-1 OR web-server-2
#
#  WHAT WE CREATE:
#    1. Target Group  → the list of EC2 instances to send traffic to
#    2. ALB           → the load balancer itself
#    3. Listener      → listens on port 80 and forwards to target group
# ============================================================


# ── 1: Target Group ───────────────────────────────────────────
# Target Group = the group of EC2 instances that receive traffic
# The ALB sends requests to healthy instances in this group

resource "aws_lb_target_group" "todo_tg" {
  name     = "TodoApp-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.todo_vpc.id

  # Health check — ALB pings / every 30 seconds
  # If an instance doesn't respond, ALB stops sending traffic to it
  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30    # check every 30 seconds
    timeout             = 5     # wait 5 seconds for response
    healthy_threshold   = 2     # 2 successes = healthy
    unhealthy_threshold = 2     # 2 failures = unhealthy
  }

  tags = { Name = "TodoApp-TG", Project = "TodoApp" }
}


# ── 2: Register EC2 instances in the Target Group ─────────────
# Tell the ALB: "send traffic to these two EC2 instances"

resource "aws_lb_target_group_attachment" "web_server_1" {
  target_group_arn = aws_lb_target_group.todo_tg.arn
  target_id        = aws_instance.web_server_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_server_2" {
  target_group_arn = aws_lb_target_group.todo_tg.arn
  target_id        = aws_instance.web_server_2.id
  port             = 80
}


# ── 3: Application Load Balancer ──────────────────────────────
# The ALB itself — internet-facing (has a public DNS name)
# Spans BOTH public subnets for high availability

resource "aws_lb" "todo_alb" {
  name               = "TodoApp-ALB"
  internal           = false       # false = internet-facing (public)
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  # ALB must be in at least 2 subnets in different AZs
  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]

  tags = { Name = "TodoApp-ALB", Project = "TodoApp" }
}


# ── 4: Listener ───────────────────────────────────────────────
# The Listener watches for incoming requests on port 80
# and forwards them to the Target Group

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.todo_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.todo_tg.arn
    # forward = send traffic to the target group
  }
}
