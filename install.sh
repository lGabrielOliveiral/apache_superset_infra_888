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
#                   INSTALAÇÃO DE PROGRAMAS
# ============================================================
# ============================================================

# Seguindo orientações segundo documentação oficial do Docker
# https://docs.docker.com/engine/install/ubuntu/

echo "Iniciando instalação do Docker..."
wait 1s
# desinstalando versões antigas
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

sudo apt-get install tree -y
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y

# Install Docker Engine, containerd, and Docker Compose.
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 
sudo docker run hello-world


# ============================================================
# ============================================================
#                   CRIAÇÃO DE ESTRUTURA BASE
# ============================================================
# ============================================================

echo "📁 Criando estrutura base em: $BASE_DIR"
mkdir -p $BASE_DIR/{terraform/datafile,ansible/{inventory,datafile},pipelines,docker}
cp ./docker-compose.yml $BASE_DIR/docker/docker-compose.yml
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
cat > $BASE_DIR/pipelines/run.sh <<'EOF'
#!/bin/bash
set -e

BASE_DIR="/opt/devops"
DOCKER_DIR="$BASE_DIR/docker"

echo "🚀 Executando pipeline de automação..."

cd "$DOCKER_DIR"

echo "🏗️ Build das imagens (terraform e ansible)..."
docker compose build

echo "🏗️ Rodando Terraform init..."
docker compose run --rm terraform init

echo "📜 Rodando Terraform plan..."
docker compose run --rm terraform plan

echo "✅ Aplicando Terraform..."
docker compose run --rm terraform apply -auto-approve

echo "⚙️ Rodando Ansible Playbook..."
docker compose run --rm ansible playbook.yml -i /ansible/inventory/hosts.ini

echo "🎉 Pipeline concluído com sucesso!"
EOF

chmod +x $BASE_DIR/pipelines/run.sh

# ------------------------------------------------------------
# Finalização
# ------------------------------------------------------------
echo "✅ Estrutura criada com sucesso!"
tree $BASE_DIR || ls -R $BASE_DIR

echo "digite '$BASE_DIR/pipelines/run.sh' para executar o pipeline de automação."



