# Infraestrutura do Banco de Dados — Oficina Mecânica

> Tech Challenge — FIAP SOAT Fase 3
> Terraform · AWS · RDS PostgreSQL

Provisiona a instância RDS usada pela aplicação
[`fiap-15soat-oficina-api`](https://github.com/KauaAlmeidaSilveira/fiap-15soat-oficina-api).

## O que este repositório cria

| Arquivo | Recursos |
|---|---|
| `data.tf` | Descobre a VPC e as subnets privadas criadas pelo repositório de Kubernetes |
| `rds.tf` | Subnet group, security group e a instância PostgreSQL |

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
- Bucket `fiap-15soat-oficina-tfstate` e tabela `fiap-15soat-oficina-tflock` já criados
- **A VPC precisa existir**: aplique antes o `fiap-15soat-oficina-infra-k8s`

## Como aplicar

```bash
cp terraform.tfvars.example terraform.tfvars   # preencher db_password
terraform init
terraform plan
terraform apply     # ~10 min
```

Depois:

```bash
terraform output rds_endpoint
```

O valor vai para o GitHub Secret `RDS_ENDPOINT` da aplicação, que o pipeline injeta no `DB_HOST`
do ConfigMap.

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

Workflow em `.github/workflows/terraform.yml`:

| Evento | O que roda |
|---|---|
| Pull request | `fmt -check`, `validate`, `plan` — o plano é comentado no próprio PR |
| Push em `main` | `apply` |
| Manual (`workflow_dispatch`) | `apply` |

O job de validação roda **sem backend**, então não precisa de credencial: um PR continua sendo
verificado mesmo com as credenciais do AWS Academy expiradas.

O `apply` está atrelado ao Environment `producao`. Configure nele um revisor obrigatório
(Settings → Environments) para exigir aprovação humana antes de qualquer mudança.

### Secrets necessários

| Secret | Origem |
|---|---|
| `AWS_ACCESS_KEY_ID` | painel do AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | painel do AWS Academy |
| `AWS_SESSION_TOKEN` | painel do AWS Academy — credenciais temporárias, expiram em poucas horas |
| `DB_PASSWORD` | a mesma senha do RDS, usada também pelo repositório da aplicação |

A senha do banco entra como `TF_VAR_db_password` direto no ambiente do job — nunca é escrita em
arquivo, então não há `terraform.tfvars` no runner para vazar em log ou artefato.

Um `concurrency group` impede duas execuções simultâneas, que disputariam o lock do DynamoDB.

## Custo

A instância RDS e o armazenamento geram custo enquanto estiverem no ar.
