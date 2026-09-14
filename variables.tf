variable "aws_region" {
  description = "Regiao AWS onde a infraestrutura e criada"
  type        = string
  default     = "us-east-1"
}

# ATENCAO: precisa ser identico em fiap-15soat-oficina-infra-k8s.
# E por este nome que data.tf encontra a VPC ("${project_name}-vpc").
variable "project_name" {
  description = "Prefixo de nome dos recursos. Contrato compartilhado entre os repos de infraestrutura."
  type        = string
  default     = "oficina"
}

variable "db_instance_class" {
  description = "Classe da instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nome do banco criado na instancia"
  type        = string
  default     = "oficina"
}

variable "db_username" {
  description = "Usuario master do banco"
  type        = string
  default     = "oficina"
}

variable "db_password" {
  description = "Senha do usuario master. Mesma do GitHub Secret DB_PASSWORD do repo da aplicacao."
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Armazenamento inicial em GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Versao do PostgreSQL"
  type        = string
  default     = "16.14"
}
