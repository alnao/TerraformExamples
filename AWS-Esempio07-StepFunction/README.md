# AWS Esempio 07 - Step Functions con S3 Copy

Questo esempio mostra come usare AWS Step Functions per orchestrare un workflow automatico che copia file tra bucket S3 e registra le operazioni tramite Lambda.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Workflow**
1. File caricato nel bucket source
2. EventBridge cattura l'evento S3 Object Created
3. EventBridge triggera la Step Function
4. Step Function esegue S3 CopyObject (da source a destination)
5. Step Function invoca Lambda per log success/failure
6. Lambda scrive log dettagliati su CloudWatch

**File di progetto**
- `main.tf`: Definizione risorse AWS (S3, Step Functions, Lambda, EventBridge)
- `variables.tf`: Variabili configurabili
- `outputs.tf`: Output utili (ARN, nomi bucket, comandi test)
- `backend.tf`: Configurazione backend remoto S3
- `lambda_function.py`: Codice Python della Lambda di logging
- `step_function_definition.json`: Definizione JSON della Step Function State Machine

**Risorse create**
- S3 Buckets: 2 bucket (source e destination) per il workflow di copia
- S3 Bucket Notification: Configurazione EventBridge per il bucket source
- Step Function State Machine: Orchestratore del workflow di copia
- Lambda Function: Function di logging che traccia le operazioni
- IAM Roles & Policies: Permessi per Step Functions e Lambda
- EventBridge Rule: Rule per catturare eventi S3 Object Created
- EventBridge Target: Target Step Function per la rule
- CloudWatch Log Groups: Log per Step Functions e Lambda
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio07StepFunction/terraform.tfstate`.

**Prerequisiti**
- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)

**Costi**
- Step Functions: $0.025 per 1.000 state transitions
- Lambda: $0.20 per milione richieste + $0.0000166667 per GB-s
- EventBridge: $1.00 per milione eventi
- S3: Storage + requests standard
- CloudWatch Logs: $0.50 per GB ingested




## Comandi
- Creazione
  ```bash
  NOME_BUCKET_SOURCE="alnao-terraform-aws-esempio07-step-source"
  NOME_BUCKET_DEST="alnao-terraform-aws-esempio07-step-dest"
  terraform init
  terraform plan
  terraform apply \
    -var="source_bucket_name=$NOME_BUCKET_SOURCE" \
    -var="destination_bucket_name=$NOME_BUCKET_DEST"
  ```
- Test

  ```bash
  # Upload file di test
  echo "Hello from Step Functions" > /tmp/test.txt
  aws s3 cp /tmp/test.txt s3://$NOME_BUCKET_SOURCE/test.txt

  # Verifica copia nel bucket destinazione
  aws s3 ls s3://$NOME_BUCKET_DEST/

  # Visualizza logs Lambda
  aws logs tail /aws/lambda/alnao-terraform-aws-esempio07-step-function-logger --follow

  # Visualizza logs Step Function
  aws logs tail /aws/vendedlogs/states/alnao-terraform-aws-esempio07-step-function --follow

  # Lista esecuzioni Step Function
  aws stepfunctions list-executions \
    --state-machine-arn $(terraform output -raw step_function_arn) \
    --max-results 10

  # Dettagli esecuzione specifica
  EXECUTION_ARN=$(aws stepfunctions list-executions \
    --state-machine-arn $(terraform output -raw step_function_arn) \
    --max-results 1 \
    --query 'executions[0].executionArn' \
    --output text)
  aws stepfunctions describe-execution --execution-arn $EXECUTION_ARN

  # Visualizza metriche Step Functions
  aws cloudwatch get-metric-statistics \
    --namespace AWS/States \
    --metric-name ExecutionsFailed \
    --dimensions Name=StateMachineArn,Value=$(terraform output -raw step_function_arn) \
    --start-time $(date -u -d '1 hour ago' --iso-8601) \
    --end-time $(date -u --iso-8601) \
    --period 300 \
    --statistics Sum
  ```
- Distruzione
  ```bash
  # Svuota buckets prima
  aws s3 rm s3://$NOME_BUCKET_SOURCE --recursive
  aws s3 rm s3://$NOME_BUCKET_DEST --recursive

  terraform destroy
  ```


## Riferimenti
- [Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Step Functions State Machine Language](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-amazon-states-language.html)
- [Step Functions AWS SDK Integrations](https://docs.aws.amazon.com/step-functions/latest/dg/supported-services-awssdk.html)
- [Step Functions Pricing](https://aws.amazon.com/step-functions/pricing/)


# &lt; AlNao /&gt;
Tutti i codici sorgente e le informazioni presenti in questo repository sono frutto di un attento e paziente lavoro di sviluppo da parte di AlNao, che si è impegnato a verificarne la correttezza nella massima misura possibile. Qualora parte del codice o dei contenuti sia stato tratto da fonti esterne, la relativa provenienza viene sempre citata, nel rispetto della trasparenza e della proprietà intellettuale. 


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
