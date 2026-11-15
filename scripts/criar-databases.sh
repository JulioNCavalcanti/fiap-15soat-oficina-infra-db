#!/bin/sh
# Cria, na RDS, um database e um usuario por servico SQL (oficina_os e oficina_execucao), cada usuario
# dono so do proprio database. Roda um pod efemero de psql dentro do cluster, porque a RDS e privada.
# Idempotente: rodar de novo so atualiza as senhas.
#
# Pre-requisitos: terraform apply deste repositorio feito, kubectl apontando para o EKS e
# terraform.tfvars com db_password (a senha do usuario master).
set -eu
cd "$(dirname "$0")/.."

HOST=$(terraform output -raw rds_endpoint)
MASTER_USER=$(sed -n 's/^db_username *= *"\(.*\)"/\1/p' terraform.tfvars)
MASTER_USER=${MASTER_USER:-oficina}
MASTER_PASSWORD=$(sed -n 's/^db_password *= *"\(.*\)"/\1/p' terraform.tfvars)
SENHAS=$(terraform output -json senhas_servicos)

[ -n "$MASTER_PASSWORD" ] || { echo "db_password nao encontrado em terraform.tfvars" >&2; exit 1; }

sql=""
for s in os execucao; do
  senha=$(printf '%s' "$SENHAS" | python3 -c "import json,sys; print(json.load(sys.stdin)['$s'])")
  sql="$sql
SELECT 'CREATE ROLE oficina_$s LOGIN' WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'oficina_$s')\\gexec
ALTER ROLE oficina_$s WITH LOGIN PASSWORD '$senha';
GRANT oficina_$s TO CURRENT_USER;
SELECT 'CREATE DATABASE oficina_$s OWNER oficina_$s' WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'oficina_$s')\\gexec
REVOKE CONNECT ON DATABASE oficina_$s FROM PUBLIC;"
done

printf '%s\n' "$sql" | kubectl run "criar-databases-$(date +%s)" --rm -i --restart=Never --quiet \
  --image=postgres:16-alpine \
  --env="PGPASSWORD=$MASTER_PASSWORD" \
  -- psql "host=$HOST port=5432 dbname=postgres user=$MASTER_USER sslmode=require" -v ON_ERROR_STOP=1

echo "Databases oficina_os e oficina_execucao prontos em $HOST"
