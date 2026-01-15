FROM nginx:alpine

# Copier notre page HTML personnalisée
COPY index.html /usr/share/nginx/html/

# Copier la configuration nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exposer le port 80
EXPOSE 80

# Variables d'environnement pour les métadonnées
ENV SERVICE_NAME="web-app"
ENV SERVICE_VERSION="1.0.0"

# Étiquettes pour Docker Swarm
LABEL service.name="web-app" \
      service.type="frontend" \
      service.version="1.0.0" \
      maintainer="tp-docker-swarm"