#!/bin/bash

# Script de vérification de l'état du cluster Docker Swarm
# Usage: ./status-check.sh [--detailed] [--json]

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
DETAILED=false
JSON_OUTPUT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --detailed)
            DETAILED=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--detailed] [--json]"
            echo "  --detailed  Affichage détaillé"
            echo "  --json      Sortie au format JSON"
            exit 0
            ;;
        *)
            echo "Option inconnue: $1"
            exit 1
            ;;
    esac
done

# Fonction d'affichage avec couleurs
print_header() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}$1${NC}"
        echo -e "${BLUE}$(echo $1 | sed 's/./=/g')${NC}"
    fi
}

print_success() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}✅ $1${NC}"
    fi
}

print_warning() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    fi
}

print_error() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}❌ $1${NC}"
    fi
}

print_info() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${CYAN}ℹ️  $1${NC}"
    fi
}

# Vérifier que Docker fonctionne
check_docker() {
    if ! docker info &> /dev/null; then
        print_error "Docker ne fonctionne pas ou n'est pas accessible"
        return 1
    fi
    return 0
}

# Vérifier l'état du swarm
check_swarm_status() {
    local swarm_status=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
    
    case "$swarm_status" in
        active)
            print_success "Swarm est actif"
            return 0
            ;;
        pending)
            print_warning "Swarm est en attente"
            return 1
            ;;
        error)
            print_error "Swarm en erreur"
            return 1
            ;;
        locked)
            print_warning "Swarm est verrouillé"
            return 1
            ;;
        *)
            print_error "Ce nœud ne fait pas partie d'un swarm"
            return 1
            ;;
    esac
}

# Collecter les informations
collect_info() {
    local info="{}"
    
    # Informations de base
    local node_id=$(docker info --format '{{.Swarm.NodeID}}' 2>/dev/null || echo "none")
    local node_role=$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)
    local swarm_status=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")
    
    if [ "$node_role" = "true" ]; then
        node_role="manager"
    else
        node_role="worker"
    fi
    
    # Compter les nœuds (seulement si manager)
    local total_nodes=0
    local manager_nodes=0
    local worker_nodes=0
    local ready_nodes=0
    
    if [ "$node_role" = "manager" ]; then
        if docker node ls &>/dev/null; then
            total_nodes=$(docker node ls --format "{{.ID}}" | wc -l)
            manager_nodes=$(docker node ls --filter "role=manager" --format "{{.ID}}" | wc -l)
            worker_nodes=$(docker node ls --filter "role=worker" --format "{{.ID}}" | wc -l)
            ready_nodes=$(docker node ls --filter "availability=active" --format "{{.ID}}" | wc -l)
        fi
    fi
    
    # Compter les services
    local total_services=0
    local running_services=0
    
    if docker service ls &>/dev/null; then
        total_services=$(docker service ls --format "{{.ID}}" | wc -l)
        # Services avec toutes leurs repliques en cours d'exécution
        running_services=$(docker service ls --format "{{.Replicas}}" | grep -c "/" || echo "0")
    fi
    
    # Compter les stacks
    local total_stacks=0
    if docker stack ls &>/dev/null; then
        total_stacks=$(docker stack ls --format "{{.Name}}" | wc -l)
    fi
    
    if [ "$JSON_OUTPUT" = true ]; then
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"node\": {"
        echo "    \"id\": \"$node_id\","
        echo "    \"role\": \"$node_role\","
        echo "    \"hostname\": \"$(hostname)\","
        echo "    \"swarm_status\": \"$swarm_status\""
        echo "  },"
        echo "  \"cluster\": {"
        echo "    \"total_nodes\": $total_nodes,"
        echo "    \"manager_nodes\": $manager_nodes,"
        echo "    \"worker_nodes\": $worker_nodes,"
        echo "    \"ready_nodes\": $ready_nodes"
        echo "  },"
        echo "  \"services\": {"
        echo "    \"total_services\": $total_services,"
        echo "    \"total_stacks\": $total_stacks"
        echo "  },"
        echo "  \"docker_version\": \"$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')\""
        echo "}"
    else
        print_header "📊 État du cluster Docker Swarm"
        echo
        print_info "Nœud actuel:"
        echo "  - ID: $node_id"
        echo "  - Rôle: $node_role"
        echo "  - Hostname: $(hostname)"
        echo "  - État Swarm: $swarm_status"
        echo
        
        if [ "$node_role" = "manager" ]; then
            print_info "Cluster:"
            echo "  - Nœuds totaux: $total_nodes"
            echo "  - Managers: $manager_nodes"
            echo "  - Workers: $worker_nodes"
            echo "  - Nœuds prêts: $ready_nodes"
            echo
        fi
        
        print_info "Services:"
        echo "  - Services totaux: $total_services"
        echo "  - Stacks déployées: $total_stacks"
        echo
        
        print_info "Docker version: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')"
    fi
}

# Affichage détaillé
show_detailed_info() {
    if [ "$JSON_OUTPUT" = true ]; then
        return
    fi
    
    print_header "🔍 Informations détaillées"
    
    # Nœuds (seulement pour les managers)
    if docker node ls &>/dev/null; then
        echo
        print_info "Nœuds du cluster:"
        docker node ls --format "table {{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.ManagerStatus}}\t{{.EngineVersion}}"
    fi
    
    # Services
    if docker service ls &>/dev/null; then
        echo
        print_info "Services actifs:"
        docker service ls --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}"
    fi
    
    # Stacks
    if docker stack ls &>/dev/null; then
        echo
        print_info "Stacks déployées:"
        docker stack ls --format "table {{.Name}}\t{{.Services}}"
    fi
    
    # Réseaux overlay
    echo
    print_info "Réseaux overlay:"
    docker network ls --filter "driver=overlay" --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
    
    # Volumes
    echo
    print_info "Volumes:"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
}

# Tests de santé
run_health_checks() {
    if [ "$JSON_OUTPUT" = true ]; then
        return
    fi
    
    print_header "🏥 Vérifications de santé"
    
    # Vérifier la connectivité inter-nœuds (pour les managers)
    if docker node ls &>/dev/null; then
        local unhealthy_nodes=$(docker node ls --filter "availability!=active" --format "{{.Hostname}}" | wc -l)
        if [ "$unhealthy_nodes" -eq 0 ]; then
            print_success "Tous les nœuds sont disponibles"
        else
            print_warning "$unhealthy_nodes nœud(s) non disponible(s)"
        fi
    fi
    
    # Vérifier les services en erreur
    if docker service ls &>/dev/null; then
        local failed_services=0
        while IFS= read -r service; do
            local replicas=$(docker service ls --filter "name=$service" --format "{{.Replicas}}")
            if [[ "$replicas" =~ ^([0-9]+)/([0-9]+)$ ]]; then
                local current="${BASH_REMATCH[1]}"
                local desired="${BASH_REMATCH[2]}"
                if [ "$current" -ne "$desired" ]; then
                    ((failed_services++))
                fi
            fi
        done < <(docker service ls --format "{{.Name}}")
        
        if [ "$failed_services" -eq 0 ]; then
            print_success "Tous les services fonctionnent correctement"
        else
            print_warning "$failed_services service(s) avec des répliques manquantes"
        fi
    fi
    
    # Vérifier l'espace disque
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        print_success "Espace disque suffisant (${disk_usage}% utilisé)"
    elif [ "$disk_usage" -lt 90 ]; then
        print_warning "Espace disque faible (${disk_usage}% utilisé)"
    else
        print_error "Espace disque critique (${disk_usage}% utilisé)"
    fi
    
    # Vérifier la mémoire
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$mem_usage" -lt 80 ]; then
        print_success "Utilisation mémoire normale (${mem_usage}%)"
    elif [ "$mem_usage" -lt 90 ]; then
        print_warning "Utilisation mémoire élevée (${mem_usage}%)"
    else
        print_error "Utilisation mémoire critique (${mem_usage}%)"
    fi
}

# Main
main() {
    if ! check_docker; then
        exit 1
    fi
    
    if ! check_swarm_status; then
        if [ "$JSON_OUTPUT" = false ]; then
            echo
            print_info "Pour initialiser un swarm: ./scripts/init-manager.sh"
            print_info "Pour rejoindre un swarm: ./scripts/join-worker.sh <TOKEN> <MANAGER_IP:PORT>"
        fi
        exit 1
    fi
    
    collect_info
    
    if [ "$DETAILED" = true ]; then
        show_detailed_info
        echo
        run_health_checks
    fi
    
    if [ "$JSON_OUTPUT" = false ]; then
        echo
        print_info "Pour plus de détails: $0 --detailed"
        print_info "Pour la sortie JSON: $0 --json"
    fi
}

# Exécution
main "$@"