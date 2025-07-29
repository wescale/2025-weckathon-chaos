#!/bin/bash
set -e

# Fonctions utilitaires pour les couleurs
function echo_info() { echo -e "\033[1;34m$1\033[0m"; }
function echo_success() { echo -e "\033[1;32m$1\033[0m"; }
function echo_warn() { echo -e "\033[1;33m$1\033[0m"; }
function echo_error() { echo -e "\033[1;31m$1\033[0m"; }

VM_NAMES=(k3s-master k3s-node1 k3s-node2)
WORKDIR="$PWD/k3s-vms"
NETWORK_NAME="k3s-net"
NETWORK_XML="$WORKDIR/$NETWORK_NAME.xml"

# Fichiers à supprimer
FILES_TO_DELETE=()
for NAME in "${VM_NAMES[@]}"; do
  FILES_TO_DELETE+=("$WORKDIR/${NAME}.qcow2" "$WORKDIR/${NAME}-cidata.iso" "$WORKDIR/${NAME}-user-data" "$WORKDIR/${NAME}-meta-data")
done
FILES_TO_DELETE+=("$NETWORK_XML")

# Entrées /etc/hosts à supprimer
HOSTS_TO_REMOVE=("192.168.100.11 k3s-master" "192.168.100.12 k3s-node1" "192.168.100.13 k3s-node2")

# --- Listing ---
echo_info "🔎 Les ressources suivantes vont être supprimées :"
echo_info "\nMachines virtuelles :"
for NAME in "${VM_NAMES[@]}"; do
  echo "  - $NAME (libvirt)"
done
echo_info "\nFichiers :"
for FILE in "${FILES_TO_DELETE[@]}"; do
  [ -e "$FILE" ] && echo "  - $FILE"
done
echo_info "\nEntrées /etc/hosts :"
for HOST in "${HOSTS_TO_REMOVE[@]}"; do
  echo "  - $HOST"
done
echo_info "\nEntrées SSH known_hosts :"
for NAME in "${VM_NAMES[@]}"; do
  echo "  - $NAME"
done

echo_warn "⚠️  Cette opération est irréversible. Continuer ? (y/n)"
read -r CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo_info "Annulation. Rien n'a été supprimé."
  exit 0
fi

# --- Suppression des VM ---
echo_info "🗑️ Suppression des VM..."
for NAME in "${VM_NAMES[@]}"; do
  if sudo virsh dominfo $NAME &>/dev/null; then
    sudo virsh destroy $NAME || true
    sudo virsh undefine $NAME --remove-all-storage || sudo virsh undefine $NAME || true
    echo_info "  - $NAME supprimée."
  else
    echo_info "  - $NAME non trouvée."
  fi
done

# --- Suppression du réseau virtuel ---
echo_info "🗑️ Suppression du réseau virtuel $NETWORK_NAME..."
if sudo virsh net-info $NETWORK_NAME &>/dev/null; then
  sudo virsh net-destroy $NETWORK_NAME || true
  sudo virsh net-undefine $NETWORK_NAME || true
  echo_info "  - Réseau $NETWORK_NAME supprimé."
else
  echo_info "  - Réseau $NETWORK_NAME non trouvé."
fi

# --- Suppression des fichiers ---
echo_info "🗑️ Suppression des fichiers liés aux VM..."
for FILE in "${FILES_TO_DELETE[@]}"; do
  if [ -e "$FILE" ]; then
    rm -f "$FILE"
    echo_info "  - $FILE supprimé."
  fi
done

# --- Nettoyage /etc/hosts ---
echo_info "🗑️ Nettoyage des entrées /etc/hosts..."
for HOST in "${HOSTS_TO_REMOVE[@]}"; do
  sudo sed -i "/$HOST/d" /etc/hosts
done

# --- Nettoyage SSH known_hosts ---
echo_info "🗑️ Nettoyage des entrées SSH known_hosts..."
for NAME in "${VM_NAMES[@]}"; do
  ssh-keygen -R $NAME &>/dev/null || true
done

echo_success "✅ Toutes les ressources du lab k3s ont été supprimées."
