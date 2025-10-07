# DEVOPS-Esempio01-Pipeline

Questo esempio dimostra una **pipeline DevOps completa** utilizzando **Terraform**, **Kubernetes** e **CI/CD** (GitLab CI o GitHub Actions) per automatizzare il ciclo Build → Test → Deploy → Verify con strategie di rollback avanzate.

## 🎯 Obiettivo

Creare una pipeline di deploy automatizzata che:
- ✅ Costruisce automaticamente le immagini Docker
- ✅ Esegue test di qualità e sicurezza  
- ✅ Deploya su più ambienti (dev, staging, production)
- ✅ Monitora la salute dell'applicazione
- ✅ Effettua rollback automatico in caso di problemi

## 📁 Struttura del Progetto

```
DEVOPS-Esempio01-Pipeline/
├── 📂 terraform/                    # Configurazione infrastruttura
│   ├── main.tf                     # Risorse Kubernetes principali
│   ├── variables.tf                # 20+ variabili parametriche
│   ├── outputs.tf                  # Output per integration
│   └── environments/               # Configurazioni per ambiente
│       ├── dev.tfvars             # DEV: 1 replica, risorse minime
│       ├── staging.tfvars         # STAGING: 2 repliche, ingress
│       └── prod.tfvars            # PROD: 3 repliche, HPA, SSL
├── 📂 app/                         # Applicazione web
│   ├── index.html                 # Dashboard Bootstrap 5 responsive
│   ├── Dockerfile                 # Container Nginx ottimizzato
│   └── nginx.conf                 # Config con endpoint salute
├── 📂 scripts/                     # Automation scripts
│   ├── deploy.sh                  # Deploy con Blue/Green strategy
│   ├── rollback.sh                # Rollback automatico avanzato
│   └── health-check.sh            # Health check multi-endpoint
├── 📂 .github/workflows/           # GitHub Actions (alternativa)
│   └── deploy.yml                 # Pipeline GitHub completa
├── .gitlab-ci.yml                 # Pipeline GitLab CI/CD
├── GITHUB_SETUP.md                # Setup per GitHub Actions
└── README.md                      # Questa documentazione
```

## 🚀 Funzionalità Pipeline

### 🏗️ **Build Stage**
- Build automatico immagini Docker
- Push su registry (GitLab/GitHub Container Registry)
- Tag automatici basati su commit SHA e branch

### 🧪 **Test Stage**  
- **Lint tests**: Validazione HTML e configurazioni
- **Security tests**: Controllo header sicurezza e configurazioni
- **Performance tests**: Test tempo di risposta (staging/prod)

### 📋 **Plan Stage**
- Terraform plan per ogni ambiente
- Artifacts condivisi tra job
- Validazione configurazioni prima del deploy

### 🚀 **Deploy Stage**
- **DEV**: Deploy automatico su push `develop`
- **STAGING**: Deploy automatico su merge `main`  
- **PRODUCTION**: Deploy manuale con approvazione
- Health check post-deploy con retry logic
- Rollback automatico se health check fallisce

### ✅ **Verify Stage**
- Test di integrazione post-deploy
- Monitoring e alerting
- Notifiche Slack/Teams

## 🏭 Ambienti

| Ambiente | Branch | Deploy | Repliche | Risorse | Features |
|----------|--------|--------|----------|---------|----------|
| **DEV** | `develop` | Automatico | 1 | Minime | Debug mode, NodePort |
| **STAGING** | `main` | Automatico | 2 | Medie | Ingress, LoadBalancer |
| **PRODUCTION** | `main` | Manuale | 3+ | Elevate | HPA, SSL, Monitoring |

## ⚙️ Prerequisiti

### Software richiesto:
- **Terraform** >= 1.0
- **kubectl** >= 1.28  
- **Docker** (per build locale)
- **Cluster Kubernetes** (minikube, kind, EKS, AKS, GKE)

### Credenziali necessarie:
- **Kubernetes**: kubeconfig per ogni ambiente
- **Docker Registry**: credenziali push/pull
- **Cloud Provider**: per backend Terraform (S3, Azure Storage, etc.)

## 🛠️ Setup Rapido

### 1. Clone del repository
```bash
git clone https://github.com/alnao/TerraformExamples.git
cd TerraformExamples/DEVOPS-Esempio01-Pipeline
```

### 2. Setup cluster Kubernetes locale
```bash
# Con minikube
minikube start --cpus=2 --memory=4g

# Con kind  
kind create cluster --name devops-pipeline

# Verifica connessione
kubectl cluster-info
```

### 3. Configurazione backend Terraform
```bash
cd terraform

# Modifica backend in main.tf per il tuo environment
# Esempio per backend locale:
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

### 4. Deploy manuale di test
```bash
# Inizializzazione
terraform init

# Plan per ambiente dev
terraform plan -var-file="environments/dev.tfvars" -var="image_tag=latest"

# Apply
terraform apply -auto-approve

# Verifica deploy
kubectl get pods -n development
kubectl get services -n development
```

### 5. Test applicazione
```bash
cd ../scripts
chmod +x health-check.sh

# Port forward per test locale
SERVICE_NAME=$(cd ../terraform && terraform output -raw service_name)
NAMESPACE=$(cd ../terraform && terraform output -raw namespace)

kubectl port-forward svc/$SERVICE_NAME -n $NAMESPACE 8080:80 &

# Health check
./health-check.sh "http://localhost:8080"

# Accedi all'app: http://localhost:8080
```

## 🔄 Configurazione CI/CD

### 📚 Per GitLab CI/CD:

1. **Configura Variables** in GitLab:
```
DOCKER_REGISTRY=registry.gitlab.com
TF_STATE_BUCKET=your-terraform-state-bucket
KUBECONFIG_DEV=base64_encoded_kubeconfig_dev
KUBECONFIG_STAGING=base64_encoded_kubeconfig_staging
KUBECONFIG_PROD=base64_encoded_kubeconfig_prod
SLACK_WEBHOOK_URL=https://hooks.slack.com/your/webhook
```

2. **Abilita Container Registry** nel progetto GitLab

3. **Push del codice**:
```bash
git add .
git commit -m "feat: setup devops pipeline"
git push origin develop  # → Deploy automatico DEV
```

### 🐙 Per GitHub Actions:

Segui la guida dettagliata in [`GITHUB_SETUP.md`](GITHUB_SETUP.md)

## 📊 Dashboard Applicazione

L'applicazione include una **dashboard interattiva** con:

- 📈 **Metriche real-time**: uptime, requests, performance
- 🏥 **Health Status**: endpoint salute e readiness
- 🔗 **API Endpoints**: `/health`, `/ready`, `/api/status`, `/metrics`
- 🎨 **UI Responsive**: Bootstrap 5 con temi personalizzati
- ⚡ **Simulazione traffico**: contatori dinamici

### Endpoint disponibili:
```bash
GET /              # Dashboard principale
GET /health        # Health check (Kubernetes liveness)
GET /ready         # Readiness check (Kubernetes readiness)  
GET /api/status    # Status API con dettagli sistema
GET /metrics       # Metriche formato Prometheus
```

## 🚨 Strategie di Rollback

### 1. **Rollback Automatico**
Attivato automaticamente se:
- Health check fallisce post-deploy
- Timeout deployment Kubernetes
- Errori critici nell'applicazione

### 2. **Rollback Manuale**
```bash
# Via script
cd scripts
./rollback.sh production previous

# Via kubectl  
kubectl rollout undo deployment/devops-app-prod -n production

# Via pipeline CI/CD
# GitLab: job manuale "rollback:prod"
# GitHub: workflow_dispatch con input ambiente
```

### 3. **Blue/Green Deployment**
Il deploy script implementa una strategia Blue/Green:
- Backup stato corrente
- Deploy nuova versione (Green)
- Health check completo
- Switch traffico o rollback se problemi

## 🔍 Monitoring e Debugging

### Log applicazione:
```bash
# Log pod correnti
kubectl logs -f deployment/devops-app-dev -n development

# Eventi Kubernetes
kubectl get events -n development --sort-by='.lastTimestamp'

# Describe deployment per troubleshooting  
kubectl describe deployment devops-app-dev -n development
```

### Metriche disponibili:
- **Health endpoints**: status applicazione
- **Kubernetes metrics**: CPU, memoria, network
- **Custom metrics**: requests, uptime, version info
- **Prometheus format**: endpoint `/metrics`

## 🔧 Personalizzazione

### Aggiungere nuovo ambiente:
1. Crea `terraform/environments/newenv.tfvars`
2. Aggiungi job pipeline per il nuovo ambiente
3. Configura kubeconfig e secrets
4. Testa deploy manualmente prima dell'automazione

### Modificare configurazione app:
1. Modifica `app/index.html` per UI changes
2. Aggiorna `app/nginx.conf` per configurazioni server
3. Rebuilda immagine Docker
4. Aggiorna variabili Terraform se necessario

### Integrare monitoring esterno:
1. Aggiungi Prometheus/Grafana nel cluster
2. Modifica endpoint `/metrics` per metriche custom
3. Configura alerting rules
4. Integra con PagerDuty/OpsGenie per alerts critici

## 📚 Risorse e Best Practice

### Terraform:
- [Provider Kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Backend Configuration](https://www.terraform.io/docs/language/settings/backends/index.html)
- [Workspace Management](https://www.terraform.io/docs/cloud/workspaces/index.html)

### Kubernetes:
- [Rolling Updates](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)  
- [Health Checks](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [HPA Guide](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

### CI/CD:
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 🤝 Contributi

Per contribuire al progetto:
1. Fork il repository
2. Crea feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push branch (`git push origin feature/amazing-feature`)  
5. Apri Pull Request

## 📝 Changelog

- **v1.0.0** - Setup iniziale pipeline GitLab CI/CD
- **v1.1.0** - Aggiunta support GitHub Actions
- **v1.2.0** - Implementazione HPA e advanced monitoring
- **v1.3.0** - Blue/Green deployment strategy



# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella misura massima possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale. 


Alcuni contenuti e porzioni di codice presenti in questo repository sono stati realizzati anche grazie al supporto di strumenti di intelligenza artificiale, il cui contributo ha permesso di arricchire e velocizzare la produzione del materiale. Ogni informazione e frammento di codice è stato comunque attentamente verificato e validato, con l’obiettivo di garantire la massima qualità e affidabilità dei contenuti offerti. 


Per ulteriori dettagli, approfondimenti o richieste di chiarimento, si invita a consultare il sito [AlNao.it](https://www.alnao.it/).


## License
Made with ❤️ by <a href="https://www.alnao.it">AlNao</a>
&bull; 
Public projects 
<a href="https://www.gnu.org/licenses/gpl-3.0"  valign="middle"> <img src="https://img.shields.io/badge/License-GPL%20v3-blue?style=plastic" alt="GPL v3" valign="middle" /></a>
*Free Software!*


Il software è distribuito secondo i termini della GNU General Public License v3.0. L'uso, la modifica e la ridistribuzione sono consentiti, a condizione che ogni copia o lavoro derivato sia rilasciato con la stessa licenza. Il contenuto è fornito "così com'è", senza alcuna garanzia, esplicita o implicita.


The software is distributed under the terms of the GNU General Public License v3.0. Use, modification, and redistribution are permitted, provided that any copy or derivative work is released under the same license. The content is provided "as is", without any warranty, express or implied.

