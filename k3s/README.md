# k3s-lab : Cluster k3s local automatisé avec QEMU/KVM et libvirt 🚀

Ce projet permet de déployer rapidement un cluster Kubernetes léger (k3s) sur 3 machines virtuelles Ubuntu, en local, sous Linux (testé sur Linux Mint), avec gestion complète du cycle de vie (création, configuration, nettoyage).

## ⚡️ Prérequis
- Linux avec sudo
- 16 Go de RAM, 20 vCPU recommandés
- QEMU/KVM, libvirt, virt-manager (installés automatiquement par le script)
- Connexion Internet (pour télécharger l'image Ubuntu cloud-init)
- Clé SSH présente dans `~/.ssh/id_ed25519.pub` ou `~/.ssh/id_rsa.pub`

## 🗂️ Structure des scripts

- **1-setup-k3s-vms.sh** :
  - Installe les dépendances nécessaires
  - Télécharge l'image Ubuntu cloud-init
  - Crée un réseau virtuel libvirt dédié
  - Crée 3 VM (k3s-master, k3s-node1, k3s-node2) avec cloud-init et accès SSH par clé
  - Met à jour `/etc/hosts` pour la résolution des noms
  - Affiche l'avancement avec des couleurs et des emojis

- **2-install-k3s-cluster.sh** :
  - Installe k3s sur le master
  - Récupère le token d'enregistrement
  - Installe k3s agent sur les nodes et les joint au cluster
  - Affiche l'avancement avec des couleurs et des emojis

- **3-configure-kubectl.sh** :
  - Récupère le kubeconfig du master
  - Modifie l'adresse du serveur pour pointer vers le master
  - Place le fichier dans `~/.kube/config`
  - Teste l'accès au cluster
  - Affiche l'avancement avec des couleurs et des emojis

- **0-cleanup-k3s-lab.sh** :
  - Liste toutes les ressources créées (VM, fichiers, réseau, /etc/hosts, known_hosts)
  - Demande confirmation avant suppression
  - Supprime les VM, fichiers cloud-init, réseau virtuel, entrées `/etc/hosts` et clés SSH
  - Affiche l'avancement avec des couleurs et des emojis

## 🚦 Utilisation

1. **Création du lab**
   ```bash
   bash 1-setup-k3s-vms.sh
   ```
2. **Installation du cluster k3s**
   ```bash
   bash 2-install-k3s-cluster.sh
   ```
3. **Configuration de kubectl**
   ```bash
   bash 3-configure-kubectl.sh
   ```
4. **Nettoyage complet**
   ```bash
   bash 0-cleanup-k3s-lab.sh
   ```

## 🔗 Accès aux VM et au cluster
- Connexion SSH :
  ```bash
  ssh ubuntu@k3s-master
  ssh ubuntu@k3s-node1
  ssh ubuntu@k3s-node2
  ```
- Vérification du cluster :
  ```bash
  kubectl get nodes
  ```

## 🛠️ Personnalisation
- Les ressources (RAM, CPU, disque) sont configurées dans `1-setup-k3s-vms.sh`.
- Le réseau virtuel est en NAT (modifiable dans le script si besoin).
- Les scripts sont conçus pour être relancés sans risque (idempotents).

## 🔒 Sécurité
- Les accès SSH se font uniquement par clé publique.
- Les VM ne sont accessibles que depuis l’hôte (réseau privé virtuel).

## 🧹 Nettoyage
- Le script `0-cleanup-k3s-lab.sh` supprime toutes les ressources créées, après confirmation.
- Les entrées `/etc/hosts` et `~/.ssh/known_hosts` sont nettoyées automatiquement.

