# ==============================
# ECS Cluster
# ==============================
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name
}

# ==============================
# ECS EC2 AMI
# ==============================
data "aws_ami" "ecs_ami" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# ==============================
# Security Group for ECS Instances
# ==============================
resource "aws_security_group" "ecs_sg" {
  name   = "ecs-sg"
  vpc_id = var.vpc_id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow traffic from ALB SG only
  ingress {
    from_port       = 1880
    to_port         = 1880
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  ingress {
    from_port       = 1883
    to_port         = 1883
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"] # MQTT can be public or restricted
  }
}

# ==============================
# IAM Role for ECS Tasks
# ==============================
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==============================
# Launch Template & ASG
# ==============================
resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "ecs-instance"
  image_id      = data.aws_ami.ecs_ami.id
  instance_type = "t3.micro"

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF
  )

  network_interfaces {
    security_groups = [aws_security_group.ecs_sg.id]
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity    = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = var.subnets

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ECS-Node"
    propagate_at_launch = true
  }
}

# ==============================
# ECS Task Definitions
# ==============================
# Node-RED
resource "aws_ecs_task_definition" "nodered" {
  family                   = "nodered-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "nodered"
    image     = var.nodered_ecr_url
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 1880
      hostPort      = 1880
    }]
  }])
}

# MQTT
resource "aws_ecs_task_definition" "mqtt" {
  family                   = "mqtt-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "mqtt"
    image     = var.mqtt_ecr_url
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 1883
      hostPort      = 1883
    }]
  }])
}

# Node.js App
resource "aws_ecs_task_definition" "nodejs_app" {
  family                   = "nodejs-app-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = "nodejs-app"
    image     = var.nodejs_app_ecr_url
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
  }])
}

# ==============================
# ECS Services
# ==============================
# Node-RED Service
resource "aws_ecs_service" "nodered" {
  name            = "nodered-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nodered.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = var.nodered_tg_arn
    container_name   = "nodered"
    container_port   = 1880
  }
}

# MQTT Service
resource "aws_ecs_service" "mqtt" {
  name            = "mqtt-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mqtt.arn
  desired_count   = 1
  launch_type     = "EC2"
}

# Node.js App Service
resource "aws_ecs_service" "nodejs_app" {
  name            = "nodejs-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nodejs_app.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = var.nodejs_app_tg_arn
    container_name   = "nodejs-app"
    container_port   = 3000
  }
}
