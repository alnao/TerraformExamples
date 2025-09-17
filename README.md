# Terraform Examples
Questo repository raccoglie una collezione di esempi pratici per l'utilizzo di Terraform su diversi provider cloud, principalmente AWS e Azure. Ogni cartella contiene un esempio autonomo, pensato per mostrare best practice, modularità e parametrizzazione.


**Terraform** è uno strumento open source per l'Infrastructure as Code (IaC) che consente di definire, gestire e versionare infrastrutture cloud tramite file di configurazione testuali. Supporta numerosi provider, tra cui AWS, Azure, Google Cloud e molti altri.


Ogni esempio è contenuto in una propria cartella (es: `AWS-Esempio01-BucketS3`, `Azure-Esempiop02-VM`) e ogni esempio include:
  - File di configurazione Terraform (main.tf, variables.tf, `outputs.tf`, ecc.)
  - Un file README.md con istruzioni specifiche
  - Eventuali moduli riutilizzabili


**Prerequisiti**:
- [Terraform](https://www.terraform.io/downloads.html) installato
- Account cloud (AWS, Azure, ecc.)
- Credenziali configurate (es. `aws configure` per AWS, variabili d'ambiente per Azure)


## Esempi
L'elenco degli esempi disponibili
- **AWS-Esempio01-BucketS3**: crea un bucket S3 parametrico su AWS, con region di default Francoforte (eu-central-1), salvataggio dello stato remoto su S3, tagging e alcune opzioni configurabili.


## Comandi principali
1. Inizializza la cartella di lavoro:
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


## Risorse utili
- [Documentazione Terraform](https://www.terraform.io/docs)
- [Provider AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Provider Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)


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



