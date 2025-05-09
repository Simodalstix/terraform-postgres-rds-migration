# Terraform: Secure RDS + Bastion + Secrets Manager Setup (SSM-Only, No SSH, No NAT)

# -----------------------------
# PROVIDERS & BACKEND
# -----------------------------
provider "aws" {
  region = var.region
}

# -----------------------------
# VPC SETUP
# -----------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.2"

  name = "rds-bastion-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_dns_hostnames = true
  single_nat_gateway   = false
}

# -----------------------------
# SECURITY GROUPS
# -----------------------------
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "SSM only, no SSH"
  vpc_id      = module.vpc.vpc_id

  # No ingress needed for SSM-only access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow PostgreSQL access from Bastion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------
# SECRETS MANAGER SECRET
# -----------------------------
resource "aws_secretsmanager_secret" "rds_secret" {
  name = "rds-postgres-creds"
}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    username = var.rds_username,
    password = var.rds_password
  })
}

# -----------------------------
# IAM ROLE FOR BASTION
# -----------------------------
resource "aws_iam_role" "bastion_ssm_role" {
  name = "bastion-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_attach" {
  role       = aws_iam_role.bastion_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "bastion_secret_access" {
  name = "bastion-secrets-access"
  role = aws_iam_role.bastion_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["secretsmanager:GetSecretValue"],
      Resource = aws_secretsmanager_secret.rds_secret.arn
    }]
  })
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "bastion-instance-profile"
  role = aws_iam_role.bastion_ssm_role.name
}

# -----------------------------
# BASTION HOST (SSM-Only)
# -----------------------------
resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_instance_profile.name

  tags = { Name = "bastion-host-ssm" }
}

# -----------------------------
# RDS INSTANCE (PostgreSQL)
# -----------------------------
resource "aws_db_instance" "postgres" {
  identifier        = "my-postgres-db"
  engine            = "postgres"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = var.rds_dbname
  username          = var.rds_username
  password          = var.rds_password
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot    = true
  publicly_accessible    = false
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# -----------------------------
# CLOUDWATCH ALARMS
# -----------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "High CPU usage on RDS"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }
}
