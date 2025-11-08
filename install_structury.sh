#!/bin/bash
# ============================================================
# Script: install.sh
# Autor: Gabriel Oliveira
# Descrição: Cria estrutura base para ambiente DevOps on-prem
# Testado em: Ubuntu 22.04 LTS
# Data: 2024-06-27
# ============================================================

# ------------------------------------------------------------
# Declaração de variáveis
# ------------------------------------------------------------
BASE_DIR="/opt/devops"

# ============================================================
# ============================================================
#                   CRIAÇÃO DE ESTRUTURA BASE
# ============================================================
# ============================================================

echo "📁 Criando estrutura base em: $BASE_DIR"
mkdir -p $BASE_DIR/ansible/{inventory,datafile}
mkdir -p $BASE_DIR/docker
mkdir -p $BASE_DIR/terraform/datafile
mkdir -p $BASE_DIR/superset/datafile/{db,redis,home}
mkdir -p $BASE_DIR/pipelines


cp ./docker-compose.yml $BASE_DIR/docker/docker-compose.devops.yml
cp ./docker-compose.yml $BASE_DIR/docker/docker-compose.superset.yml
# ------------------------------------------------------------
# Terraform
# ------------------------------------------------------------
cat > $BASE_DIR/terraform/Dockerfile <<'EOF'
FROM hashicorp/terraform:1.9
WORKDIR /workspace
ENTRYPOINT ["terraform"]
EOF

cat > $BASE_DIR/terraform/main.tf <<'EOF'
# Terraform main configuration file
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "local" {}

resource "local_file" "example" {
  content  = "Hello, Power DevOps!"
  filename = "${path.module}/example.txt"
}
EOF

cat > $BASE_DIR/terraform/backend.tf <<'EOF'
# Backend configuration (local by default)
terraform {
  backend "local" {
    path = "/datafile/terraform.tfstate"
  }
}
EOF

# ------------------------------------------------------------
# Ansible
# ------------------------------------------------------------
cat > $BASE_DIR/ansible/Dockerfile <<'EOF'
FROM alpine:3.20
RUN apk add --no-cache ansible openssh-client bash
WORKDIR /ansible
ENTRYPOINT ["ansible-playbook"]
EOF

cat > $BASE_DIR/ansible/playbook.yml <<'EOF'
---
- name: Example Ansible Playbook
  hosts: all
  become: yes
  tasks:
    - name: Test connection
      ping:
EOF

cat > $BASE_DIR/ansible/inventory/hosts.ini <<'EOF'
[all]
localhost ansible_connection=local
EOF

# ------------------------------------------------------------
# Pipelines
# ------------------------------------------------------------
cat > /opt/devops/pipelines/run.sh <<'EOF'
#!/bin/bash
set -e

BASE_DIR="/opt/devops"
DOCKER_DIR="$BASE_DIR/docker"
COMPOSE_DEVOPS="$DOCKER_DIR/docker-compose.devops.yml"

echo "🚀 Executando pipeline de automação..."

cd "$DOCKER_DIR"

echo "🏗️ Build das imagens (terraform e ansible)..."
docker compose -f "$COMPOSE_DEVOPS" build

echo "🏗️ Rodando Terraform init (reconfigure)..."
docker compose -f "$COMPOSE_DEVOPS" run --rm terraform init -reconfigure

echo "📜 Rodando Terraform plan..."
docker compose -f "$COMPOSE_DEVOPS" run --rm terraform plan

echo "✅ Aplicando Terraform..."
docker compose -f "$COMPOSE_DEVOPS" run --rm terraform apply -auto-approve

echo "⚙️ Rodando Ansible Playbook..."
docker compose -f "$COMPOSE_DEVOPS" run --rm ansible playbook.yml -i /ansible/inventory/hosts.ini

echo "🎉 Pipeline concluído com sucesso!"
EOF

chmod +x /opt/devops/pipelines/run.sh


# ------------------------------------------------------------
# Finalização
# ------------------------------------------------------------
echo "✅ Estrutura criada com sucesso!"
tree $BASE_DIR || ls -R $BASE_DIR

echo "digite '$BASE_DIR/pipelines/run.sh' para executar o pipeline de automação."



