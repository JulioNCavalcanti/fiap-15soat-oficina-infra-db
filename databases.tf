# Um database e um usuario por servico SQL, na mesma instancia (decidido em 08/11/2026).
# A RDS e privada, entao o Terraform nao alcanca o PostgreSQL: so gera as senhas.
# Quem cria databases e usuarios e scripts/criar-databases.sh, de dentro do cluster.
locals {
  databases_servicos = toset(["os", "execucao"])
}

resource "random_password" "servico" {
  for_each = local.databases_servicos
  length   = 24
  special  = false
}
