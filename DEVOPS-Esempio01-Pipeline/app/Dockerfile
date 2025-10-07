FROM nginx:alpine

# Copia i file dell'applicazione
COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Label per GitHub Container Registry
LABEL org.opencontainers.image.source="https://github.com/alnao/TerraformExamples"
LABEL org.opencontainers.image.description="DevOps Pipeline Example Application"

# Crea directory per i log
RUN mkdir -p /var/log/nginx

# Crea endpoint per health check
RUN echo '{"status":"ok","service":"devops-app","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > /usr/share/nginx/html/health.json
RUN echo '{"ready":true,"checks":{"database":"ok","redis":"ok"},"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > /usr/share/nginx/html/ready.json

# Crea endpoint per status API
RUN mkdir -p /usr/share/nginx/html/api
RUN echo '{"status":"OK","version":"1.0.0","environment":"${ENVIRONMENT:-production}","uptime":"'$(uptime)'"}' > /usr/share/nginx/html/api/status.json

# Crea endpoint per metriche (formato Prometheus-like)
RUN echo -e '# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{method="GET",status="200"} 1234\nhttp_requests_total{method="POST",status="200"} 567\n# HELP app_uptime_seconds Application uptime in seconds\n# TYPE app_uptime_seconds gauge\napp_uptime_seconds 3600' > /usr/share/nginx/html/metrics.txt

# Esponi la porta 80
EXPOSE 80

# Avvia nginx
CMD ["nginx", "-g", "daemon off;"]
