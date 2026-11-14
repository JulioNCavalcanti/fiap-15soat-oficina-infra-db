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
