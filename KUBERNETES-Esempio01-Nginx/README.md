# KUBERNETES-Esempio01-Nginx

Questo modulo Terraform crea un deployment Nginx su un cluster Kubernetes locale (per esempio con minikube) con ConfigMap per file HTML personalizzati, utile come esempio di test e base di partenza per uno sviluppo futuro.


## Prerequisiti
- Terraform >= 1.0
- Cluster Kubernetes locale (minikube, kind, k3s, ecc.)
- kubectl configurato (`~/.kube/config`)


## Variabili principali
- `docker_image_name`: Nome dell'immagine Docker (default: nginx)
- `deployment_name`: Nome del deployment Kubernetes (default: nginx-deployment)
- `service_name`: Nome del service Kubernetes (default: nginx-service)
- `configmap_name`: Nome della ConfigMap per HTML (default: nginx-html)
- `external_port`: Porta del service (default: 80)
- `internal_port`: Porta interna del container (default: 80)
- `node_port`: NodePort per accesso esterno (default: 30080)
- `replicas`: Numero di repliche del deployment (default: 1)
- `html_directory`: Directory locale con file HTML (default: html)
- `namespace`: Namespace Kubernetes (default: default)


## Esempio di utilizzo
```hcl
module "nginx_k8s" {
  source          = "./KUBERNETES-Esempio01-Nginx"
  deployment_name = "mio-nginx"
  replicas        = 2
  node_port       = 30080
  html_directory  = "html"
}
```


## Setup cluster locale
### Con minikube:
```bash
# Installare e avviare minikube
minikube start
# Verificare
kubectl get nodes
```


## Comandi principali
1. Inizializzare la cartella:
   ```bash
   terraform init
   ```
2. Visualizzare il piano di esecuzione:
   ```bash
   terraform plan
   ```
3. Applicare la configurazione (crea risorse K8s):
   ```bash
   terraform apply
   ```
4. Distruggiere le risorse:
   ```bash
   terraform destroy
   minikube stop
   ```

## Accedere all'applicazione
Dopo il deploy, accedere a Nginx tramite:
- **minikube**: `minikube service nginx-service --url`
- **kind**: `kubectl port-forward service/nginx-service 8080:80`
- **NodePort**: `http://localhost:30080` (se supportato)
- **FreeLens**: se disponibile


## Note
- I file HTML sono caricati tramite ConfigMap
- Il deployment supporta scalabilità orizzontale
- Self-healing automatico in caso di failure
- Rolling updates per aggiornamenti zero-downtime



# < AlNao />
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella misura massima possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale.

Alcuni contenuti e porzioni di codice presenti in questo repository sono stati realizzati anche grazie al supporto di strumenti di intelligenza artificiale, il cui contributo ha permesso di arricchire e velocizzare la produzione del materiale. Ogni informazione e frammento di codice è stato comunque attentamente verificato e validato, con l'obiettivo di garantire la massima qualità e affidabilità dei contenuti offerti.

Per ulteriori dettagli, approfondimenti o richieste di chiarimento, si invita a consultare il sito [AlNao.it](https://www.alnao.it/).

## License
Made with ❤️ by <a href="https://www.alnao.it">AlNao</a>
&bull; 
Public projects 
<a href="https://www.gnu.org/licenses/gpl-3.0"  valign="middle"> <img src="https://img.shields.io/badge/License-GPL%20v3-blue?style=plastic" alt="GPL v3" valign="middle" /></a>
*Free Software!*

Il software è distribuito secondo i termini della GNU General Public License v3.0. L'uso, la modifica e la ridistribuzione sono consentiti, a condizione che ogni copia o lavoro derivato sia rilasciato con la stessa licenza. Il contenuto è fornito "così com'è", senza alcuna garanzia, esplicita o implicita.

The software is distributed under the terms of the GNU General Public License v3.0. Use, modification, and redistribution are permitted, provided that any copy or derivative work is released under the same license. The content is provided "as is", without any warranty, express or implied.
