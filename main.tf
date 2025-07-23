# main.tf - Infraestrutura AWS para API + Postgres

provider "aws" {
  region = var.aws_region
}

# Obter a VPC default

data "aws_vpc" "default" {
  default = true
}

# Obter subnets da VPC default (uma por AZ)
data "aws_subnet" "default_a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.aws_region}a"
  default_for_az    = true
}
data "aws_subnet" "default_b" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.aws_region}b"
  default_for_az    = true
}

# Obter o security group default da VPC default
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "group-name"
    values = ["default"]
  }
}

# --- Networking: Subnets, NAT Gateway, Route Tables ---

# 1. Subnets públicas (para ALB e NAT Gateway)
resource "aws_subnet" "public_a" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.100.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "public-a" }
}
resource "aws_subnet" "public_b" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.101.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = { Name = "public-b" }
}

# 2. Subnets privadas (para ECS, RDS)
resource "aws_subnet" "private_a" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.110.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "private-a" }
}
resource "aws_subnet" "private_b" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.111.0/24"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "private-b" }
}

# 3. Internet Gateway (já existe na VPC default, mas para subnets novas pode ser útil referenciar)
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 4. Elastic IP para NAT Gateway
resource "aws_eip" "nat" {
  # vpc = true (removido, não é mais suportado)
}

# 5. NAT Gateway em subnet pública
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  depends_on    = [aws_eip.nat]
}

# 6. Route Table para subnets públicas
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default.id
  }
  tags = { Name = "public-rt" }
}
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# 7. Route Table para subnets privadas (com rota para NAT)
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = { Name = "private-rt" }
}
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# --- Ajustar recursos para usar as novas subnets ---

# ALB em subnets públicas
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.6.0"

  name               = "api-alb"
  load_balancer_type = "application"
  vpc_id             = data.aws_vpc.default.id
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb.id]

  # Substituir listeners por http_tcp_listeners
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name_prefix      = "api"
      backend_protocol = "HTTP"
      backend_port     = 3000
      target_type      = "ip"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/todos"
        matcher             = "200-399"
        healthy_threshold   = 2
        unhealthy_threshold = 2
      }
    }
  ]

  access_logs = {
    bucket  = aws_s3_bucket.alb_logs.bucket
    enabled = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "api-ecs-cluster"
}

# IAM Role para ECS Task
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# S3 Bucket para logs do ALB
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.project_name}-alb-logs-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Permissão para o ALB gravar logs no bucket
resource "aws_s3_bucket_policy" "alb_logs_policy" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" },
        Action = ["s3:PutObject"],
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      }
    ]
  })
}

# CloudWatch Log Group para ECS
resource "aws_cloudwatch_log_group" "ecs_api" {
  name              = "/ecs/api"
  retention_in_days = 14
}

# ECS Task Definition e Service (simplificado, ajuste conforme sua imagem)
resource "aws_ecs_task_definition" "api" {
  family                   = "api-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.api_image
      essential = true
      portMappings = [{ containerPort = 3000, hostPort = 3000 }]
      environment = [
        { name = "DB_HOST", value = module.db.db_instance_address },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_USER", value = var.db_user },
        { name = "DB_PASS", value = var.db_password },
        { name = "DB_NAME", value = var.db_name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])
}

# RDS em subnets privadas
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.7.0"

  identifier = "todos-db"
  engine            = "postgres"
  engine_version    = "16.3"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = var.db_name
  username          = var.db_user
  password          = var.db_password
  port              = 5432
  family            = "postgres16"

  vpc_security_group_ids = [data.aws_security_group.default.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  db_subnet_group_name = aws_db_subnet_group.default.name
  multi_az             = false
  manage_master_user_password = false
}

resource "aws_db_subnet_group" "default" {
  name       = "default-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# ECS Service em subnets privadas
resource "aws_security_group" "ecs" {
  name        = "ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "api" {
  name            = "api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = "api"
    container_port   = 3000
  }
  depends_on = [module.alb]
}

resource "aws_security_group_rule" "rds_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.default.id
  source_security_group_id = aws_security_group.ecs.id
  description              = "Allow ECS tasks to access RDS"
} 