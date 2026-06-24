module "network" {
    source = "./modules/network"
    cidr_block_vpc = var.cidr_block_vpc
    public_subnets  = var.public_subnets
    private_subnets = var.private_subnets
    region = var.region

}

resource "aws_instance" "bastion" {
  ami                     = var.ami
  instance_type           = "t3.micro"
  subnet_id = module.network.public_subnet_ids[0]
  associate_public_ip_address  = true
   vpc_security_group_ids = [
    aws_security_group.allow_ssh.id
  ]
  key_name = "devops-project"
  provisioner "local-exec" {
    command = "echo The bastion\\'s IP address is ${self.public_ip}"
  }
      tags = {
  Name = "bastion-test"
}
}

resource "aws_instance" "application" {
  ami                     = var.ami
  instance_type           = "t3.micro"
  subnet_id = module.network.private_subnet_ids[0]
   vpc_security_group_ids = [
    aws_security_group.second_sg.id
  ]
  key_name = "devops-project"
  tags = {
  Name = "application-ec2"
}
}

resource "aws_security_group" "second_sg" {
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.network.vpc_cidr]
  }
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

}

resource "aws_security_group" "allow_ssh" {
  vpc_id = module.network.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_ses_email_identity" "my_ses" {
  email = "alaaatef3200@gmail.com"
}

# IAM role for Lambda execution
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_execution_role_${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "test_policy_${terraform.workspace}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Package the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/index.js"
  output_path = "${path.module}/function.zip"
}

# Lambda function
resource "aws_lambda_function" "lambda_func" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "example_lambda_function_${terraform.workspace}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  code_sha256   = data.archive_file.lambda_zip.output_base64sha256

  runtime = "nodejs16.x"

environment {
  variables = {
   region = var.region
  }
}
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_lambda_permission" "allow_s3" {
  count = terraform.workspace == "dev" ? 1 : 0
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_func.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::mys3-state-file"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count  = terraform.workspace == "dev" ? 1 : 0
  bucket = "mys3-state-file"

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_func.arn
    events              = ["s3:ObjectCreated:*"]

    filter_suffix = "terraform.tfstate"
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}


resource "aws_db_subnet_group" "mysql_subnets" {
  name = "mysql-subnet-group"

  subnet_ids = module.network.private_subnet_ids
}

resource "aws_security_group" "rds_sg" {
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [module.network.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "first-mysql" {
  identifier = "mysql-db-${terraform.workspace}"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  db_name  = "appdb"
  username = "admin"
  password = "Admin12345" 

  db_subnet_group_name   = aws_db_subnet_group.mysql_subnets.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
  publicly_accessible  = false
}

resource "aws_elasticache_subnet_group" "redis_subnets" {
  name = "redis-subnet-group"

  subnet_ids = module.network.private_subnet_ids
}

resource "aws_security_group" "redis_sg" {
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.network.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-${terraform.workspace}"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"

  subnet_group_name = aws_elasticache_subnet_group.redis_subnets.name
  security_group_ids = [aws_security_group.redis_sg.id]
}

resource "aws_security_group" "alb_sg" {
  vpc_id = module.network.vpc_id

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

resource "aws_security_group_rule" "alb_to_app_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"

  security_group_id        = aws_security_group.second_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.network.public_subnet_ids

  tags = {
    Environment = "${terraform.workspace}"
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  name     = "alb-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.network.vpc_id
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
  }

resource "aws_lb_target_group_attachment" "alb_tg_attach" {
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.application.id
  port             = 3000
}

resource "aws_security_group" "jenkins_ansible_sg" {
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
tags = {
  Name = "jenkins-ansible-sg"
}
}

resource "aws_instance" "jenkins_ansible" {
  ami                     = var.ami
  instance_type           = "t3.small"
  subnet_id = module.network.public_subnet_ids[0]
  associate_public_ip_address  = true
   vpc_security_group_ids = [
    aws_security_group.jenkins_ansible_sg.id
  ]
  key_name = "devops-project"
  root_block_device{
    volume_size = 20
  }

      tags = {
  Name = "jenkins_ansible"
}
}
