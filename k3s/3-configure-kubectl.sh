#!/bin/bash
set -e

# Fonctions utilitaires pour les couleurs
function echo_info() { echo -e "\033[1;34m$1\033[0m"; }
function echo_success() { echo -e "\033[1;32m$1\033[0m"; }
function echo_warn() { echo -e "\033[1;33m$1\033[0m"; }
function echo_error() { echo -e "\033[1;31m$1\033[0m"; }

MASTER=k3s-master
USER=ubuntu
KUBECONFIG_DIR="$HOME/.kube"
KUBECONFIG_FILE="$KUBECONFIG_DIR/config"
TMP_K3S_YAML="/tmp/k3s.yaml"

# 1. Récupérer le fichier k3s.yaml depuis le master
echo_info "📥 Récupération du fichier kubeconfig depuis $MASTER..."
scp $USER@$MASTER:/etc/rancher/k3s/k3s.yaml $TMP_K3S_YAML

# 2. Modifier l'adresse du serveur pour pointer vers le master sur le réseau
echo_info "✏️  Modification de l'adresse du serveur dans le kubeconfig..."
MASTER_IP=$(getent hosts $MASTER | awk '{print $1}')
sed -i "s|127.0.0.1|$MASTER_IP|g" $TMP_K3S_YAML

# 3. Créer le dossier ~/.kube si besoin et déplacer le fichier
echo_info "📂 Déplacement du kubeconfig dans $KUBECONFIG_FILE..."
mkdir -p "$KUBECONFIG_DIR"
mv $TMP_K3S_YAML "$KUBECONFIG_FILE"
chmod 600 "$KUBECONFIG_FILE"

echo_success "✅ Fichier kubeconfig copié et configuré dans $KUBECONFIG_FILE"

# 4. Tester l'accès au cluster
echo_info "🔎 Test de connexion au cluster k3s..."
kubectl --kubeconfig="$KUBECONFIG_FILE" get nodes
if [ $? -eq 0 ]; then
  echo_success "🎉 Connexion à k3s OK !"
else
  echo_error "❌ Échec de la connexion à k3s. Vérifie la configuration."
  exit 1
fi
