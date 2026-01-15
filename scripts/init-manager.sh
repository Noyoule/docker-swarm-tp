#!/bin/bash

# Script d'initialisation du manager Docker Swarm
# Usage: ./init-manager.sh [IP_ADDRESS]

set -e

echo "🚀 Initialisation du Docker Swarm Manager"
echo "========================================="

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

# Vérifier que Docker fonctionne
if ! docker info &> /dev/null; then
    echo "❌ Docker ne fonctionne pas. Vérifiez que le service Docker est démarré."
    echo "   sudo systemctl start docker"
    exit 1
fi

# Déterminer l'IP à utiliser
if [ $# -eq 1 ]; then
    MANAGER_IP="$1"
    echo "📍 Utilisation de l'IP spécifiée: $MANAGER_IP"
else
    # Essayer de détecter l'IP automatiquement
    MANAGER_IP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p' | head -1)
    if [ -z "$MANAGER_IP" ]; then
        echo "❌ Impossible de détecter automatiquement l'IP."
        echo "   Usage: $0 <IP_ADDRESS>"
        echo "   Exemple: $0 192.168.1.10"
        exit 1
    fi
    echo "📍 IP détectée automatiquement: $MANAGER_IP"
fi

# Vérifier si un swarm existe déjà
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "⚠️  Un swarm est déjà actif sur cette machine."
    echo "   Pour réinitialiser: docker swarm leave --force"
    read -p "   Voulez-vous continuer et quitter le swarm existant? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Sortie du swarm existant..."
        docker swarm leave --force
    else
        echo "❌ Arrêt de l'initialisation."
        exit 1
    fi
fi

echo "🔧 Initialisation du swarm avec l'IP: $MANAGER_IP"
docker swarm init --advertise-addr "$MANAGER_IP"

if [ $? -eq 0 ]; then
    echo "✅ Swarm initialisé avec succès!"
    echo ""
    echo "📋 Informations du cluster:"
    docker node ls
    echo ""
    echo "🔑 Token pour les workers:"
    echo "   Exécutez cette commande sur les machines workers:"
    docker swarm join-token worker
    echo ""
    echo "🔑 Token pour les managers:"
    echo "   Exécutez cette commande sur les machines managers supplémentaires:"
    docker swarm join-token manager
    echo ""
    echo "💡 Commandes utiles:"
    echo "   - Voir les nœuds: docker node ls"
    echo "   - État du swarm: docker info | grep -A 10 'Swarm:'"
    echo "   - Créer un service: docker service create --name web --publish 8080:80 nginx"
    echo ""
    echo "🎉 Le manager Swarm est prêt à recevoir des workers!"
else
    echo "❌ Erreur lors de l'initialisation du swarm."
    exit 1
fi