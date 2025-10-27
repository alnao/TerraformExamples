# AWS-Esempio01-BucketS3

Questo modulo Terraform crea un bucket S3 parametrico su AWS, con region di default Francoforte (eu-central-1), salvataggio dello stato remoto su S3, tagging e molte opzioni configurabili.


## Variabili principali
- `region`: Regione AWS (default: eu-central-1)
- `bucket_name`: Nome del bucket S3
- `tags`: Mappa di tag da applicare
- `versioning_enabled`: Abilita versioning (default: true)
- `force_destroy`: Cancella bucket anche se non vuoto


## Esempio di utilizzo
```hcl
module "bucket" {
  source              = "./Esempio01BucketS3"
  region              = "eu-central-1"
  bucket_name         = "esempio01bucketS3-alnao"
  tags                = {
    Environment = "Test"
    Owner       = "alnao"
    Example     = "Esempio01bucketS3"
  }
  versioning_enabled  = true
  force_destroy       = false
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
3. Applica la configurazione:
   ```bash
   terraform apply
   ```
4. Distruggi le risorse:
   ```bash
   terraform destroy
   ```

## Note
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio01bucketS3/terraform.tfstate`.
- Modifica le variabili nel file `variables.tf` o tramite CLI/TFVARS per personalizzare il comportamento.


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



