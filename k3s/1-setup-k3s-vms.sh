#!/bin/bash
set -e

# Variables 
VM_NAMES=(k3s-master k3s-node1 k3s-node2)
VM_CPUS=(2 2 2)
VM_RAM=(3072 2048 2048) # en Mo
VM_DISK=(30 20 20)      # en Go
CLOUD_IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
CLOUD_IMG="jammy-server-cloudimg-amd64.img"
WORKDIR="$PWD/k3s-vms"
NETWORK_NAME="k3s-net"
NETWORK_XML="$WORKDIR/$NETWORK_NAME.xml"

# Fonctions utilitaires 
function echo_info() { echo -e "\033[1;34m$1\033[0m"; }
function echo_success() { echo -e "\033[1;32m$1\033[0m"; }
function echo_warn() { echo -e "\033[1;33m$1\033[0m"; }
function echo_error() { echo -e "\033[1;31m$1\033[0m"; }

# Préparation 
echo_info "🔧 Installation des dépendances..."
sudo apt update && sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst cloud-image-utils wget

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Téléchargement de l'image cloud-init Ubuntu 
echo_info "⬇️ Téléchargement de l'image Ubuntu Server 22.04 cloud-init..."
if [ ! -f "$CLOUD_IMG" ]; then
    wget -O "$CLOUD_IMG" "$CLOUD_IMG_URL"
else
    echo_info "Image déjà présente."
fi

# Récupération de la clé publique SSH 
echo_info "🔑 Récupération de la clé publique SSH..."
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    PUBKEY=$(cat "$HOME/.ssh/id_ed25519.pub")
elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    PUBKEY=$(cat "$HOME/.ssh/id_rsa.pub")
else
    echo_error "Aucune clé SSH trouvée dans ~/.ssh. Générez-en une avec ssh-keygen."
    exit 1
fi

# Création du réseau virtuel libvirt 
echo_info "🌐 Création du réseau virtuel libvirt ($NETWORK_NAME)..."
if ! sudo virsh net-info $NETWORK_NAME &>/dev/null; then
    cat > "$NETWORK_XML" <<EOF
<network>
  <name>$NETWORK_NAME</name>
  <bridge name="virbr20"/>
  <forward mode="nat"/>
  <ip address="192.168.100.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.100.10" end="192.168.100.100"/>
EOF
for i in 0 1 2; do
  MAC="52:54:00:00:10:0$((i+1))"
  IP="192.168.100.$((11+i))"
  HOST="${VM_NAMES[$i]}"
  cat >> "$NETWORK_XML" <<EOF
      <host mac="$MAC" name="$HOST" ip="$IP"/>
EOF
done
cat >> "$NETWORK_XML" <<EOF
    </dhcp>
  </ip>
</network>
EOF
    sudo virsh net-define "$NETWORK_XML"
    sudo virsh net-autostart $NETWORK_NAME
    sudo virsh net-start $NETWORK_NAME
else
    echo_info "Réseau $NETWORK_NAME déjà existant."
fi

# Création des VM 
for i in 0 1 2; do
  NAME="${VM_NAMES[$i]}"
  CPU="${VM_CPUS[$i]}"
  RAM="${VM_RAM[$i]}"
  DISK="${VM_DISK[$i]}"
  MAC="52:54:00:00:10:0$((i+1))"
  IP="192.168.100.$((11+i))"

  echo_info "💽 Préparation du disque pour $NAME..."
  if [ ! -f "$WORKDIR/${NAME}.qcow2" ]; then
    qemu-img create -f qcow2 -b "$CLOUD_IMG" -F qcow2 "$WORKDIR/${NAME}.qcow2" ${DISK}G
  fi

  echo_info "📝 Génération du cloud-init pour $NAME..."
  cat > "$WORKDIR/${NAME}-user-data" <<EOF
#cloud-config
hostname: $NAME
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users,admin
    home: /home/ubuntu
    shell: /bin/bash
    ssh-authorized-keys:
      - $PUBKEY
ssh_pwauth: false
disable_root: true
preserve_hostname: false
EOF
  cat > "$WORKDIR/${NAME}-meta-data" <<EOF
instance-id: $NAME
local-hostname: $NAME
EOF
  cloud-localds "$WORKDIR/${NAME}-cidata.iso" "$WORKDIR/${NAME}-user-data" "$WORKDIR/${NAME}-meta-data"

  echo_info "🚀 Création et démarrage de la VM $NAME..."
  if ! sudo virsh dominfo $NAME &>/dev/null; then
    sudo virt-install \
      --name $NAME \
      --ram $RAM \
      --vcpus $CPU \
      --os-variant ubuntu22.04 \
      --disk path="$WORKDIR/${NAME}.qcow2",format=qcow2 \
      --disk path="$WORKDIR/${NAME}-cidata.iso",device=cdrom \
      --network network=$NETWORK_NAME,mac=$MAC \
      --graphics none \
      --noautoconsole \
      --import
  else
    echo_info "VM $NAME déjà existante."
    sudo virsh start $NAME
  fi

done

# Mise à jour du /etc/hosts local 
echo_info "📝 Mise à jour de /etc/hosts pour la résolution des noms..."
for i in 0 1 2; do
  IP="192.168.100.$((11+i))"
  HOST="${VM_NAMES[$i]}"
  if ! grep -q "$IP" /etc/hosts; then
    echo "$IP $HOST" | sudo tee -a /etc/hosts
  fi
done

echo_success "🎉 Toutes les VM sont prêtes et démarrées !"
echo_info "➡️  Accès SSH : ssh ubuntu@k3s-master (ou k3s-node1, k3s-node2)"
echo_info "🟢 Pour vérifier les IP : ping k3s-master, etc."
