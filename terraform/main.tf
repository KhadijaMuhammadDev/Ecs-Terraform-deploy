data "aws_elb_service_account" "main" {}




resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${lower(var.project_name)}-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${lower(var.project_name)}-igw"
  }
}




resource "aws_subnet" "public" {
  count                   = length(var.available_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.available_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${lower(var.project_name)}-public-${var.available_zones[count.index]}"
    Tier = "Public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.available_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 100)
  availability_zone = var.available_zones[count.index]

  tags = {
    Name = "${lower(var.project_name)}-private-${var.available_zones[count.index]}"
    Tier = "Private"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.available_zones)
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = length(var.available_zones)
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id
}




resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.available_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.available_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.available_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}



resource "aws_security_group" "alb" {
  name   = "${lower(var.project_name)}-alb-sg"
  vpc_id = aws_vpc.main.id

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

resource "aws_security_group" "ecs_tasks" {
  name   = "${lower(var.project_name)}-ecs-tasks-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
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

resource "aws_security_group" "db" {
  name   = "${lower(var.project_name)}-db-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ecs_to_db_ingress" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.db.id
}





resource "aws_ecs_cluster" "main" {
  name = "${lower(var.project_name)}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecr_repository" "app_repo" {
  name = "${lower(var.project_name)}-app"

  image_scanning_configuration {
    scan_on_push = true
  }
}




resource "aws_db_subnet_group" "db" {
  name       = "${lower(var.project_name)}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${lower(var.project_name)}-rds-credentials"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_password.result
  })
}

resource "aws_db_instance" "main" {
  identifier             = "${lower(var.project_name)}-rds"
  engine                 = "postgres"
  engine_version = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.db.name
  skip_final_snapshot    = true
  username               = "dbadmin"
  password               = random_password.db_password.result
  vpc_security_group_ids = [aws_security_group.db.id]
}




resource "aws_s3_bucket" "alb_logs" {
  bucket = "${lower(var.project_name)}-alb-logs-98765-finalnti-log-bucket"

  tags = {
    Name = "${lower(var.project_name)}-alb-logs"
  }
}

resource "aws_s3_bucket_versioning" "alb_logs_versioning" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "alb_logs_policy" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowExternalService"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      },
      {
        Sid    = "AllowExternalServiceAccess"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = ["s3:GetBucketAcl"]
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

resource "aws_lb" "main" {
  count              = 0
  name               = "${lower(var.project_name)}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    enabled = true
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${lower(var.project_name)}-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path = "/"
  }
}

#resource "aws_lb_listener" "http" {
 # load_balancer_arn = aws_lb.main.arn
  #port              = 80
  #protocol          = "HTTP"

  #default_action {
   # type             = "forward"
   # target_group_arn = aws_lb_target_group.app.arn
  #}
#}
