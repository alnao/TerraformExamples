# GitHub Secrets necessari per la pipeline

Per usare questa pipeline GitHub Actions, devi configurare i seguenti **secrets** nel tuo repository GitHub:

## 📊 AWS Secrets (per backend Terraform S3)
```
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key  
TF_STATE_BUCKET=terraform-devops-pipeline-state
```

## ☸️ Kubernetes Secrets (kubeconfig base64)
```bash
# Per ogni ambiente, codifica il kubeconfig in base64:
cat ~/.kube/config | base64 -w 0

# Poi aggiungi ai GitHub Secrets:
KUBECONFIG_DEV=base64_encoded_kubeconfig_dev
KUBECONFIG_STAGING=base64_encoded_kubeconfig_staging  
KUBECONFIG_PROD=base64_encoded_kubeconfig_prod
```

## 🔔 Notification Secrets (opzionali)
```
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your/webhook/url
```

## 🏭 GitHub Container Registry

La pipeline usa **GitHub Container Registry (ghcr.io)** automaticamente.
Le immagini saranno pubblicate su: `ghcr.io/your-username/terraformexamples/devops-app`

### Abilitare GHCR:
1. Vai su **Settings** → **Actions** → **General**
2. Sotto **Workflow permissions** seleziona **Read and write permissions**
3. Abilita **Allow GitHub Actions to create and approve pull requests**

## 🚀 Come usare la pipeline:

### Deploy automatico:
- **Push su `develop`** → Deploy su DEV
- **Push/merge su `main`** → Deploy su STAGING
- **Deploy PRODUCTION** → Manuale via GitHub UI

### Rollback manuale:
1. Vai su **Actions** tab
2. Seleziona **DevOps Pipeline**
3. Clicca **Run workflow**
4. Scegli l'ambiente per il rollback

### Environment Protection Rules:
Per sicurezza, configura **Environment Protection Rules**:

1. Vai su **Settings** → **Environments**
2. Per **production**:
   - ✅ **Required reviewers** (aggiungi team/utenti)
   - ✅ **Wait timer** (es: 5 minuti)
   - ✅ **Deployment branches** (solo `main`)

## 🔄 Differenze principali da GitLab:

| Aspetto | GitLab CI | GitHub Actions |
|---------|-----------|----------------|
| **File config** | `.gitlab-ci.yml` | `.github/workflows/*.yml` |
| **Registry** | registry.gitlab.com | ghcr.io |
| **Secrets** | Variables/Secrets UI | Settings → Secrets |
| **Environments** | Environments UI | Settings → Environments |
| **Manual jobs** | `when: manual` | `workflow_dispatch` |
| **Artifacts** | artifacts: | actions/upload-artifact |

## 🛠️ Setup locale per test:

```bash
# 1. Clona il repo
git clone https://github.com/your-username/TerraformExamples.git

# 2. Setup cluster locale (minikube/kind)  
minikube start

# 3. Test deploy locale
cd DEVOPS-Esempio01-Pipeline/terraform
terraform init
terraform plan -var-file="environments/dev.tfvars" -var="image_tag=latest"
terraform apply -auto-approve

# 4. Test health check
cd ../scripts
chmod +x health-check.sh
kubectl port-forward svc/devops-app-service -n development 8080:80 &
./health-check.sh "http://localhost:8080"
```
