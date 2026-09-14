# Descobre a rede criada por fiap-15soat-oficina-infra-k8s.
#
# Optamos por data source em vez de terraform_remote_state: assim este repo nao
# precisa de permissao de leitura no state do outro, e o acoplamento fica na
# convencao de nomes, que ja existia (o modulo de VPC nomeia "${project_name}-vpc").
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-vpc-private-*"]
  }
}

data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}
