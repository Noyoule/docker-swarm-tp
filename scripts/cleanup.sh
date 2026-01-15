#!/bin/bash

# Script de nettoyage complet du Docker Swarm
# Usage: ./cleanup.sh [--force]

set -e

echo "🧹 Nettoyage du Docker Swarm"
echo "============================"

FORCE_MODE=false
if [ "$1" = "--force" ]; then
    FORCE_MODE=true
    echo "⚠️  Mode force activé - pas de confirmation"
fi

# Vérifier que Docker fonctionne
if ! docker info &> /dev/null; then
    echo "❌ Docker ne fonctionne pas. Impossible de nettoyer."
    exit 1
fi

# Vérifier si on fait partie d'un swarm
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "ℹ️  Cette machine ne fait pas partie d'un swarm actif."
    echo "   Rien à nettoyer."
    exit 0
fi

# Confirmation si pas en mode force
if [ "$FORCE_MODE" = false ]; then
    echo "⚠️  Cette opération va:"
    echo "   - Supprimer toutes les stacks déployées"
    echo "   - Supprimer tous les services"
    echo "   - Faire quitter cette machine du swarm"
    echo "   - Nettoyer les réseaux et volumes orphelins"
    echo ""
    read -p "   Êtes-vous sûr de vouloir continuer? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Nettoyage annulé."
        exit 0
    fi
fi

echo "🔍 Analyse de l'état actuel du swarm..."

# Déterminer si on est manager ou worker
NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)

if [ "$NODE_ROLE" = "true" ]; then
    echo "👑 Cette machine est un manager Swarm."
    
    # Supprimer toutes les stacks
    echo "📦 Suppression des stacks..."
    STACKS=$(docker stack ls --format "{{.Name}}" 2>/dev/null || true)
    if [ -n "$STACKS" ]; then
        for stack in $STACKS; do
            echo "   - Suppression de la stack: $stack"
            docker stack rm "$stack"
        done
        echo "⏳ Attente de la suppression complète des stacks..."
        sleep 10
    else
        echo "   Aucune stack trouvée."
    fi
    
    # Supprimer tous les services restants
    echo "🔧 Suppression des services individuels..."
    SERVICES=$(docker service ls --format "{{.ID}}" 2>/dev/null || true)
    if [ -n "$SERVICES" ]; then
        for service in $SERVICES; do
            echo "   - Suppression du service: $service"
            docker service rm "$service"
        done
        echo "⏳ Attente de la suppression complète des services..."
        sleep 5
    else
        echo "   Aucun service individuel trouvé."
    fi
    
    # Lister les autres nœuds avant de quitter
    echo "📋 Nœuds dans le cluster:"
    docker node ls
    
    # Vérifier s'il y a d'autres managers
    OTHER_MANAGERS=$(docker node ls --filter role=manager --format "{{.Hostname}}" | grep -v "$(hostname)" | wc -l)
    CURRENT_NODE_ID=$(docker info --format '{{.Swarm.NodeID}}')
    
    if [ "$OTHER_MANAGERS" -gt 0 ]; then
        echo "👥 Autres managers détectés. Rétrogradation en worker avant de quitter..."
        docker node demote "$CURRENT_NODE_ID"
        sleep 2
        docker swarm leave
    else
        echo "👑 Dernier manager - forçage de la sortie du swarm..."
        docker swarm leave --force
    fi
else
    echo "👷 Cette machine est un worker Swarm."
    echo "🚪 Sortie du swarm..."
    docker swarm leave
fi

# Nettoyage des ressources Docker
echo "🧽 Nettoyage des ressources Docker orphelines..."

# Supprimer les réseaux overlay orphelins
echo "   - Nettoyage des réseaux..."
docker network prune -f

# Supprimer les volumes orphelins
echo "   - Nettoyage des volumes..."
docker volume prune -f

# Supprimer les conteneurs arrêtés
echo "   - Nettoyage des conteneurs..."
docker container prune -f

# Supprimer les images inutilisées (optionnel)
if [ "$FORCE_MODE" = true ]; then
    echo "   - Nettoyage des images inutilisées..."
    docker image prune -a -f
fi

echo "✅ Nettoyage terminé!"
echo ""
echo "📊 État final:"
docker system df
echo ""
echo "💡 Pour rejoindre un nouveau swarm:"
echo "   - En tant que worker: ./join-worker.sh <TOKEN> <MANAGER_IP:PORT>"
echo "   - En tant que manager: ./init-manager.sh [IP_ADDRESS]"