# TP Docker Swarm - Migration Cloud

# Membres du groupe 

- AFOMALE Komi David Frank
- NOYOULIWA Essowaza Victoire
- LIMDEYOU Médar Essossinam
- NAPO Kossi M’PAKA
- AKAKPO Remi Eli Kokou
- BOTRE LARE Aboudou

## Objectifs du TP

Ce TP vous permettra de découvrir et maîtriser Docker Swarm, la solution native d'orchestration de conteneurs de Docker. À la fin de ce TP, vous saurez :

- Initialiser un cluster Docker Swarm
- Ajouter des nœuds worker au cluster
- Déployer des applications multi-services
- Gérer la scalabilité et la haute disponibilité
- Surveiller et maintenir un cluster Swarm

## Prérequis

- Docker installé sur au moins 2 machines (ou VMs)
- Accès root ou sudo sur les machines
- Connectivité réseau entre les machines
- Connaissances de base de Docker et Docker Compose

## Architecture du TP

```
📁 docker-swarm-tp/
├── 📄 README.md                 # Ce fichier
├── 📁 applications/             # Applications d'exemple
│   ├── web-app/                 # Application web simple
│   └── api/                     # API REST
├── 📁 stacks/                   # Fichiers Docker Compose pour stacks
│   ├── web-stack.yml            # Stack application web
│   ├── monitoring-stack.yml     # Stack monitoring
│   └── database-stack.yml       # Stack base de données
└── 📁 monitoring/               # Outils de monitoring
    ├── visualizer.yml           # Visualiseur du cluster
    └── status-check.sh          # Script de vérification d'état
```

## Étapes du TP

### Étape 1: Préparation des machines

#### Machine 1 (Manager)
```bash
# Vérifier que Docker est installé et démarré
sudo systemctl status docker
sudo systemctl start docker

# Vérifier la version
docker --version
```

#### Machine 2 (Worker)
```bash
# Même vérification que pour le manager
sudo systemctl status docker
sudo systemctl start docker
docker --version
```

### Étape 2: Initialisation du Swarm

#### Sur la machine Manager (192.168.1.10)

1. **Initialiser le swarm**
```bash
# Cloner ce TP
git clone <url-du-repo>

```bash
# Initialiser le swarm avec l'IP du manager par exemple 192.168.1.10
docker swarm init --advertise-addr 192.168.1.10 

# Récupérer le token pour les workers
docker swarm join-token worker
```

2. **Vérifier l'état du swarm**
```bash
docker node ls
```

### Étape 3: Rejoindre le swarm

#### Sur la machine Worker (192.168.1.11)

```bash
# Copier les scripts sur la machine worker
scp -r scripts/ user@192.168.1.11:~/

# Se connecter à la machine worker
ssh user@192.168.1.11


```bash
docker swarm join --token <TOKEN> 192.168.1.10:2377
```

### Étape 4: Vérification du cluster

#### Sur le manager

```bash
# Vérifier que les nœuds sont bien connectés
docker node ls

# Afficher les détails d'un nœud
docker node inspect <NODE-ID>

# Voir l'état du swarm
docker system info | grep -A 10 "Swarm:"
```

### Étape 5: Déploiement d'applications

#### Déploiement d'une application simple

```bash
# Déployer un service nginx simple
docker service create --name web-server --publish 8080:80 --replicas 3 nginx

# Vérifier le service
docker service ls
docker service ps web-server

# Tester l'accès
curl http://192.168.1.10:8080
curl http://192.168.1.11:8080
```

#### Déploiement d'une stack complète

```bash
# Déployer la stack web complète
docker stack deploy -c stacks/web-stack.yml web-app

# Vérifier la stack
docker stack ls
docker stack services web-app
```

### Étape 6: Monitoring et visualisation

```bash
# Déployer le visualiseur du cluster
docker stack deploy -c monitoring/visualizer.yml viz

# Accéder au visualiseur
# http://192.168.1.10:8081
```

## Commandes utiles

### Gestion des services
```bash
# Lister les services
docker service ls

# Scaler un service
docker service scale web-server=5

# Mettre à jour un service
docker service update --image nginx:alpine web-server

# Supprimer un service
docker service rm web-server
```

### Gestion des nœuds
```bash
# Lister les nœuds
docker node ls

# Promouvoir un worker en manager
docker node promote <NODE-ID>

# Rétrograder un manager en worker
docker node demote <NODE-ID>

# Drainer un nœud (maintenance)
docker node update --availability drain <NODE-ID>

# Remettre un nœud en service
docker node update --availability active <NODE-ID>
```

### Gestion des stacks
```bash
# Lister les stacks
docker stack ls

# Voir les services d'une stack
docker stack services <STACK-NAME>

# Voir les tâches d'une stack
docker stack ps <STACK-NAME>

# Supprimer une stack
docker stack rm <STACK-NAME>
```

## Nettoyage

Pour nettoyer complètement l'environnement :

```bash
# Supprimer toutes les stacks
docker stack rm $(docker stack ls --format "{{.Name}}")

# Supprimer tous les services
docker service rm $(docker service ls -q)

# Quitter le swarm (sur les workers)
docker swarm leave

# Quitter le swarm (sur le manager)
docker swarm leave --force
```

## Ressources complémentaires

- [Documentation officielle Docker Swarm](https://docs.docker.com/engine/swarm/)
- [Docker Swarm vs Kubernetes](https://docs.docker.com/get-started/orchestration/)
- [Best practices pour Docker Swarm](https://docs.docker.com/engine/swarm/admin_guide/)
