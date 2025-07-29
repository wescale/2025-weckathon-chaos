#!/bin/bash
set -e

# Fonctions utilitaires pour les couleurs
function echo_info() { echo -e "\033[1;34m$1\033[0m"; }
function echo_success() { echo -e "\033[1;32m$1\033[0m"; }
function echo_warn() { echo -e "\033[1;33m$1\033[0m"; }
function echo_error() { echo -e "\033[1;31m$1\033[0m"; }

# Variables
MASTER=k3s-master
NODES=(k3s-node1 k3s-node2)
USER=ubuntu

# 1. Installer k3s sur le master
echo_info "🚀 Installation de k3s sur le master ($MASTER)..."
ssh $USER@$MASTER "curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644"

# 1b. Attendre que le token soit disponible
MAX_WAIT=120
WAITED=0
echo_info "⏳ Attente de l'apparition du token k3s sur le master..."
while ! ssh $USER@$MASTER "sudo test -s /var/lib/rancher/k3s/server/node-token"; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    echo_error "❌ [ERREUR] Le token k3s n'est pas apparu sur le master après $MAX_WAIT secondes."
    exit 1
  fi
  echo_info "⏳ ... $WAITED/$MAX_WAIT s"
  sleep 2
  WAITED=$((WAITED+2))
done

echo_info "🔑 Récupération du token k3s..."
TOKEN=$(ssh $USER@$MASTER "sudo cat /var/lib/rancher/k3s/server/node-token")
MASTER_IP=$(getent hosts $MASTER | awk '{print $1}')

# 3. Installer k3s agent sur chaque node
for NODE in "${NODES[@]}"; do
  echo_info "🚀 Installation de k3s agent sur $NODE..."
  ssh $USER@$NODE "curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN sh -s -"
done

echo_success "✅ Cluster k3s déployé !"
echo_info "🔎 Pour vérifier les noeuds : ssh $USER@$MASTER 'kubectl get nodes'"
