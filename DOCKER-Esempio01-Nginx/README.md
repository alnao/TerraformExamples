# DOCKER-Esempio01-Nginx

Questo modulo Terraform crea un container Docker Nginx nel sistema *locale* tramite provider Docker, utile per test e sviluppo in locale.

## Variabili principali
- `docker_image_name`: Nome dell'immagine Docker (default: nginx)
- `container_name`: Nome del container (default: tutorial)
- `external_port`: Porta esterna esposta (default: 8001)
- `internal_port`: Porta interna del container (default: 80)
- `keep_image_locally`: Mantieni immagine dopo destroy (default: false)
- `html_directory`: Directory locale con file HTML (default: html)

## Esempio di utilizzo
```hcl
module "nginx" {
  source              = "./DOCKER-Esempio01-Nginx"
  docker_image_name   = "nginx"
  container_name      = "mio-nginx"
  external_port       = 8080
  html_directory      = "html"
}
```


## Comandi principali
1. Inizializza la cartella:
   ```bash
   terraform init
   ```
2. Visualizza il piano di esecuzione:
   ```bash
   terraform plan
   ```
3. Applica la configurazione (crea il container):
   ```bash
   terraform apply
   ```
4. Distruggi le risorse (rimuove il container):
   ```bash
   terraform destroy
   ```

## Note
- È necessario avere Docker installato e in esecuzione sulla macchina locale, [AlNao Debian HandBook](https://github.com/alnao/alnao/blob/main/DEBIAN.md) per una guida di installazione di Docker e Terraform in sistemi GNU Linux Debian
- Il container Nginx è accessibile su http://localhost:8001 (o la porta impostata nelle variabili)


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
