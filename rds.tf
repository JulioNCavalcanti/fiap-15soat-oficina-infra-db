resource "aws_db_subnet_group" "oficina" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Permite acesso ao RDS apenas a partir das subnets privadas da VPC"
  vpc_id      = data.aws_vpc.main.id

  # Antes este ingress referenciava module.eks.node_security_group_id, o que
  # amarrava este repositorio ao de Kubernetes. Liberar por CIDR das subnets
  # privadas da o mesmo alcance de rede (os nodes do EKS vivem nelas) sem
  # nenhuma dependencia entre os dois states.
  ingress {
    description = "PostgreSQL a partir das subnets privadas (onde rodam os nodes do EKS)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [for s in data.aws_subnet.private : s.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "oficina" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp2"
  storage_encrypted     = false

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.oficina.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false # single-AZ para reduzir custo em ambiente de estudo

  skip_final_snapshot        = true
  deletion_protection        = false
  backup_retention_period    = 1
  auto_minor_version_upgrade = true
}
