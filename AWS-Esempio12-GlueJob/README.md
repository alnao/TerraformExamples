# AWS Esempio 12 - Glue Job con Step Function

Esempio Terraform che replica il flusso CloudFormation di Esempio13glueJob:
- upload file Excel su S3
- EventBridge intercetta l'evento
- Lambda `start_process` avvia la Step Function
- Step Function invoca Lambda `excel2csv`
- se la condizione `flag_processo` e vera, Step Function avvia Glue Job
- Lo script Glue filtra le righe con campi `nome`/`cognome` validi e `18 < eta < 42` e scrive un file di output!

- Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati.

## File di progetto

- `main.tf`: risorse AWS (S3, EventBridge, Lambda, Step Functions, Glue, IAM)
- `variables.tf`: variabili configurabili
- `outputs.tf`: output utili
- `backend.tf`: backend remoto S3
- `terraform.tfvars.example`: esempio configurazione
- `step_function_definition.json`: definizione workflow
- `lambda/start_process.py`: trigger Step Function
- `lambda/excel2csv.py`: conversione Excel -> CSV
- `glue/etl_code.py`: script Glue ETL

## Risorse create

- 1 bucket S3 per input/output/codice Glue
- 2 Lambda (`start_process`, `excel2csv`)
- 1 Step Function state machine
- 1 Glue Job (`glueetl`)
- 1 rule EventBridge su eventi `Object Created`
- IAM roles e policy minime per Glue/Lambda/Step Functions
- CloudWatch log groups

## Prerequisiti

1. AWS CLI configurato
2. Terraform >= 1.0
3. Permessi IAM per S3, Lambda, EventBridge, Step Functions, Glue, CloudWatch, IAM
4. Layer Lambda con `openpyxl` per la funzione `excel2csv`

## Setup

### 1. Region

```bash
export AWS_REGION=eu-central-1
```

### 2. Crea layer openpyxl

```bash
mkdir -p /tmp/es12/python && pip install openpyxl -t /tmp/es12/python/
(cd /tmp/es12 && zip -r /tmp/es12/openpyxl-layer.zip python && rm -rf /tmp/es12/python)
aws lambda publish-layer-version \
  --layer-name openpyxl \
  --zip-file fileb:///tmp/es12/openpyxl-layer.zip \
  --compatible-runtimes python3.11 \
  --region $AWS_REGION
```

Aggiorna `terraform.tfvars` con l'ARN restituito.

### 3. Deploy

```bash
cd AWS-Esempio12-GlueJob
cat terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Test rapido

Carica un file Excel di test nel path input:

```bash
BUCKET_NAME=$(terraform output -raw bucket_name)
aws s3 cp ./persone.xlsx s3://$BUCKET_NAME/INPUT/excel/persone.xlsx
```

Controlla esecuzioni Step Function:

```bash
SF_ARN=$(terraform output -raw step_function_arn)
aws stepfunctions list-executions --state-machine-arn $SF_ARN --max-results 10
```

Controlla run Glue:

```bash
GLUE_JOB=$(terraform output -raw glue_job_name)
aws glue get-job-runs --job-name $GLUE_JOB --max-results 10
```

## Cleanup

```bash
BUCKET_NAME=$(terraform output -raw bucket_name)
aws s3 rm s3://$BUCKET_NAME --recursive
terraform destroy
```

## Note

- La Lambda `excel2csv` richiede il layer `openpyxl`.




# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella massima misura possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale. 


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
