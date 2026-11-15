# Infraestrutura do Banco de Dados — Oficina Mecânica

> Tech Challenge — FIAP SOAT Fase 4
> Terraform · AWS · RDS PostgreSQL · DynamoDB

Provisiona os bancos dos microsserviços da Fase 4: uma instância RDS PostgreSQL com um database e um
usuário por serviço SQL (OS e Execução) e a tabela DynamoDB do Billing.

## O que este repositório cria

| Arquivo | Recursos |
|---|---|
| `data.tf` | Descobre a VPC e as subnets privadas criadas pelo repositório de Kubernetes |
| `rds.tf` | Subnet group, security group e a instância PostgreSQL |
| `databases.tf` | Senhas dos usuários `oficina_os` e `oficina_execucao` (o database e o usuário são criados por `scripts/criar-databases.sh`) |
| `dynamodb.tf` | Tabela única `oficina-billing`, com o GSI esparso `outbox-pendente` e TTL da inbox |

## Arquitetura

```
   ┌───────────────────────────────────────┐
   │          subnets privadas             │
   │   ┌─────────────┐                     │
   │   │ nodes EKS   │───┐                 │
   │   └─────────────┘   │ 5432            │
   │                     ▼                 │
   │            ┌──────────────────┐       │
   │            │  RDS PostgreSQL  │       │  publicly_accessible = false
   │            └──────────────────┘       │  single-AZ (custo)
   └───────────────────────────────────────┘
              VPC criada pelo infra-k8s
```

O security group libera a porta 5432 **apenas** a partir dos CIDRs das subnets privadas — onde
vivem os nodes do EKS. A instância não é acessível pela internet.

## Tecnologias

- Terraform >= 1.5, provider AWS ~> 5.60
- PostgreSQL 16 em `db.t3.micro`
- Backend de state em S3 com lock em DynamoDB

## Pré-requisitos

- Credenciais AWS configuradas
- Bucket `fiap-15soat-oficina-fase4-tfstate` e tabela `fiap-15soat-oficina-tflock` já criados
- **A VPC precisa existir**: aplique antes o `fiap-15soat-oficina-infra-k8s`

## Como aplicar

Na Fase 4 o `apply` é manual (GitHub Actions bloqueado) e faz parte do `scripts/subir-aws.sh` do
repositório do OS, que também gera a senha do usuário master em `terraform.tfvars` (gitignorado).
Separadamente:

```bash
cp terraform.tfvars.example terraform.tfvars   # preencher db_password
terraform init
terraform apply                                # ~10 min
sh scripts/criar-databases.sh                  # depois do apply, com kubectl apontando para o EKS
```

A RDS é privada, então o Terraform não alcança o PostgreSQL: `criar-databases.sh` roda um pod efêmero
de `psql` dentro do cluster e cria `oficina_os` e `oficina_execucao`, cada um com usuário dono só do
próprio database. Os serviços leem a senha do `terraform output senhas_servicos` no deploy.

## Por que este repositório não depende do state do outro

A versão anterior amarrava o security group do RDS ao dos nodes do EKS
(`module.eks.node_security_group_id`), o que obrigaria a ler o state do repositório de Kubernetes.

Agora a liberação é por **CIDR das subnets privadas**, descobertas via data source filtrando
`tag:Name = "${project_name}-vpc"`. Mesmo alcance de rede, sem acoplamento de state e sem precisar
de permissão de leitura no bucket do outro repositório.

O preço é um contrato de nomes: `project_name` **precisa ser idêntico** ao do
`fiap-15soat-oficina-infra-k8s`. Divergir faz o `data source` não encontrar a VPC, e o `plan` falha
com erro claro — o que é preferível a falhar silenciosamente.

## Ordem de destruição

Destrua este repositório **antes** do `infra-k8s`: a VPC não pode ser removida enquanto houver
uma instância RDS dentro dela.

```bash
terraform destroy
```

## CI/CD

O workflow `.github/workflows/terraform.yml` (plan em PR, apply em `main` com aprovação no Environment
`producao`) continua no repositório, mas o GitHub Actions da conta está bloqueado por billing. Na Fase 4
o `apply` e o `destroy` são manuais, pela conta AWS pessoal do Júlio, com os scripts do repositório do OS
(`scripts/subir-aws.sh` e `scripts/destruir-aws.sh`).

## Custo

A instância RDS e o armazenamento geram custo enquanto estiverem no ar.
