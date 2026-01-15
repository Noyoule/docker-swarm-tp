#!/bin/bash

# Script pour rejoindre un Docker Swarm en tant que worker
# Usage: ./join-worker.sh <TOKEN> <MANAGER_IP:PORT>

set -e

echo "🔗 Rejoindre le Docker Swarm en tant que Worker"
echo "=============================================="

# Vérifier les arguments
if [ $# -ne 2 ]; then
    echo "❌ Usage incorrect."
    echo "   Usage: $0 <TOKEN> <MANAGER_IP:PORT>"
    echo "   Exemple: $0 SWMTKN-1-xxxxx 192.168.1.10:2377"
    echo ""
    echo "💡 Pour obtenir le token, exécutez sur le manager:"
    echo "   docker swarm join-token worker"
    exit 1
fi

TOKEN="$1"
MANAGER_ADDRESS="$2"

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

# Vérifier si cette machine fait déjà partie d'un swarm
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "⚠️  Cette machine fait déjà partie d'un swarm."
    echo "   Pour quitter: docker swarm leave"
    read -p "   Voulez-vous quitter le swarm actuel et rejoindre le nouveau? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Sortie du swarm actuel..."
        docker swarm leave
    else
        echo "❌ Arrêt de l'opération."
        exit 1
    fi
fi

# Tester la connectivité avec le manager
echo "🔍 Test de connectivité avec le manager ($MANAGER_ADDRESS)..."
MANAGER_IP=$(echo "$MANAGER_ADDRESS" | cut -d: -f1)
MANAGER_PORT=$(echo "$MANAGER_ADDRESS" | cut -d: -f2)

if ! ping -c 1 "$MANAGER_IP" &> /dev/null; then
    echo "❌ Impossible de joindre le manager à l'adresse $MANAGER_IP"
    echo "   Vérifiez la connectivité réseau et l'adresse IP."
    exit 1
fi

# Tenter de rejoindre le swarm
echo "🔗 Tentative de rejoindre le swarm..."
if docker swarm join --token "$TOKEN" "$MANAGER_ADDRESS"; then
    echo "✅ Worker ajouté avec succès au swarm!"
    echo ""
    echo "📋 Informations locales:"
    docker info | grep -A 10 "Swarm:"
    echo ""
    echo "💡 Commandes utiles pour ce worker:"
    echo "   - Voir les services: docker service ls"
    echo "   - Voir les tâches sur ce nœud: docker ps"
    echo "   - Quitter le swarm: docker swarm leave"
    echo ""
    echo "🎉 Ce nœud fait maintenant partie du cluster Swarm!"
else
    echo "❌ Erreur lors de la tentative de rejoindre le swarm."
    echo "   Vérifiez:"
    echo "   - Le token est correct et valide"
    echo "   - L'adresse du manager est accessible"
    echo "   - Les ports 2377 (management), 7946 (communication) et 4789 (overlay) sont ouverts"
    exit 1
fi