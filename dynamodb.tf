# Banco NoSQL do Billing: tabela unica com orcamento, cobranca, outbox e inbox.
resource "aws_dynamodb_table" "billing" {
  name         = "${var.project_name}-billing"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "outboxPendente"
    type = "S"
  }

  attribute {
    name = "criadoEm"
    type = "S"
  }

  # Indice esparso: so as mensagens ainda nao publicadas tem o atributo outboxPendente.
  global_secondary_index {
    name            = "outbox-pendente"
    hash_key        = "outboxPendente"
    range_key       = "criadoEm"
    projection_type = "ALL"
  }

  # Limpa a inbox depois de 14 dias, o mesmo tempo de retencao das filas.
  ttl {
    attribute_name = "expiraEm"
    enabled        = true
  }
}
