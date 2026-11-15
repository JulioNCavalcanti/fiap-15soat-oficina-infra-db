output "rds_endpoint" {
  description = "Endpoint a usar no DB_HOST do ConfigMap da aplicacao (sem a porta)"
  value       = aws_db_instance.oficina.address
}

output "rds_port" {
  value = aws_db_instance.oficina.port
}

output "dynamodb_billing_tabela" {
  description = "Nome da tabela do Billing"
  value       = aws_dynamodb_table.billing.name
}

output "databases_servicos" {
  description = "Database e usuario de cada servico SQL (criados por scripts/criar-databases.sh)"
  value       = { for s in local.databases_servicos : s => { database = "oficina_${s}", usuario = "oficina_${s}" } }
}

output "senhas_servicos" {
  description = "Senha do usuario de cada servico; vai para o Secret do servico no Kubernetes"
  value       = { for s, senha in random_password.servico : s => senha.result }
  sensitive   = true
}
