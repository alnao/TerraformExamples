# AWS Esempio 09 - Amazon DynamoDB

Questo esempio mostra come creare e gestire una tabella Amazon DynamoDB con Terraform, includendo configurazioni avanzate come indexes, streams, autoscaling, backup e global tables per replica multi-region.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Architettura DynamoDB**
1. Applicazione invia richiesta di lettura/scrittura a DynamoDB
2. DynamoDB router distribuisce la richiesta alle partizioni appropriate
3. Dati vengono letti/scritti con cifratura automatica at-rest
4. DynamoDB Streams (opzionale) cattura le modifiche
5. Lambda/Kinesis può consumare lo stream per processamento eventi
6. CloudWatch monitora metriche e throttling
7. Autoscaling (PROVISIONED mode) adatta la capacità al carico
8. Point-in-Time Recovery mantiene backup continuo ultimi 35 giorni
9. Global Tables replica dati in real-time tra regioni

**File di progetto**
- `main.tf`: Definizione risorse AWS (DynamoDB Table, GSI, LSI, Streams, Autoscaling, CloudWatch Alarms, Global Tables)
- `compute.tf`: Lambda function triggered by S3 via EventBridge per salvare metadata file in DynamoDB
- `variables.tf`: Variabili configurabili (billing mode, capacity, keys, indexes, streams, TTL, encryption)
- `outputs.tf`: Output utili (ARN tabella, stream ARN, chiavi, billing mode, Lambda ARN, S3 bucket)
- `backend.tf`: Configurazione backend remoto S3
- `lambda_s3_to_dynamodb.py`: Codice Python Lambda per processare eventi S3 e salvare in DynamoDB

**Risorse create**
- DynamoDB Table: Tabella NoSQL serverless con schema flessibile
  - Global Secondary Indexes (GSI): Indici con diversa partition key per query alternative
  - Local Secondary Indexes (LSI): Indici con stessa partition key ma diverso sort key
  - DynamoDB Streams: Change Data Capture per integrazione con Lambda/Kinesis
  - Point-in-Time Recovery: Backup continuo ultimi 35 giorni con restore point-in-time
  - Server-Side Encryption: Cifratura automatica at-rest con AWS managed o customer managed CMK
  - TTL Configuration: Eliminazione automatica item scaduti basata su timestamp
  - Application Auto Scaling: Target tracking per read/write capacity (PROVISIONED mode)
  - Auto Scaling Policies: Politiche per adattamento automatico al carico
  - CloudWatch Metric Alarms: Allarmi per read/write throttle events
  - DynamoDB Table Replicas: Replica multi-region per global tables (opzionale)
- Compute system
  - S3 Bucket: Bucket trigger per eventi file upload
  - Lambda Function: Function per processare eventi S3 e salvare metadata in DynamoDB
  - EventBridge Rule: Rule per catturare eventi S3 Object Created/Deleted
  - EventBridge Target: Target Lambda per eventi S3
  - IAM Roles & Policies: Permessi Lambda per DynamoDB, S3 e CloudWatch
  - CloudWatch Log Groups: Logs per Lambda function
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio09DynamoDB/terraform.tfstate`.

**Prerequisiti**
- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)
- AWS CLI per operazioni CRUD (opzionale)
- jq per parsing JSON (opzionale)

**Costi stimati**
- **PAY_PER_REQUEST (On-Demand)**
  - Write Request Units: $1.25 per milione WRU
  - Read Request Units: $0.25 per milione RRU
  - Storage: $0.25 per GB/mese
  - Backup on-demand: $0.10 per GB
  - PITR: +$0.20 per GB/mese
  - Streams: $0.02 per 100k read requests
  - Global Tables replication: $1.875 per milione replicated WRU
  - **Esempio costo mensile On-Demand:**
    - 1M write requests: $1.25
    - 10M read requests: $2.50
    - 10 GB storage: $2.50
    - PITR enabled: $2.00
    - **Totale**: ~$8.25/mese
- **PROVISIONED**
  - Read Capacity Unit (RCU): $0.00065/ora per RCU (eu-central-1)
  - Write Capacity Unit (WCU): $0.00065/ora per WCU (eu-central-1)
  - Storage: $0.25 per GB/mese
  - Autoscaling: incluso, no extra charges
  - Esempio costo mensile Provisioned (10 RCU, 10 WCU):**
    - 10 RCU × $0.00065 × 730 ore: $4.75
    - 10 WCU × $0.00065 × 730 ore: $4.75
    - 10 GB storage: $2.50
    - PITR: $2.00
    - **Totale**: ~$14/mese (copre ~260M read e ~26M write strongly consistent)

## Comandi
- Inizializzazione e deploy base
  ```bash
  # Inizializzazione backend
  terraform init

  # Preview modifiche
  terraform plan

  # Deploy base con On-Demand billing
  terraform apply 
  ```
  - Deploy completo con tutte le features
    ```
    # Deploy completo con tutte le features
    terraform apply \
      -var="table_name=my-app-table" \
      -var="hash_key=userId" \
      -var="range_key=timestamp" \
      -var="range_key_type=N" \
      -var="stream_enabled=true" \
      -var="ttl_enabled=true" \
      -var="ttl_attribute_name=expiresAt" \
      -var="enable_point_in_time_recovery=true" \
      -var="enable_cloudwatch_alarms=true"
    ```
  - Deploy con Provisioned mode e autoscaling
    ```bash
    # Provisioned mode base
    terraform apply \
      -var="table_name=my-dynamodb-table" \
      -var="billing_mode=PROVISIONED" \
      -var="read_capacity=10" \
      -var="write_capacity=5"

    # Con autoscaling per gestire picchi di traffico
    terraform apply \
      -var="table_name=my-dynamodb-table" \
      -var="billing_mode=PROVISIONED" \
      -var="read_capacity=5" \
      -var="write_capacity=5" \
      -var="enable_autoscaling=true" \
      -var="autoscaling_read_max_capacity=100" \
      -var="autoscaling_write_max_capacity=50" \
      -var="autoscaling_target_value=70"
    ```
  - Deploy con Global Secondary Indexes
    ```bash
    # Crea terraform.tfvars per GSI complessi
    cat > terraform.tfvars <<'EOF'
    table_name = "users-table"
    hash_key = "userId"
    hash_key_type = "S"

    additional_attributes = [
      {
        name = "email"
        type = "S"
      },
      {
        name = "createdAt"
        type = "N"
      },
      {
        name = "status"
        type = "S"
      }
    ]

    global_secondary_indexes = [
      {
        name            = "EmailIndex"
        hash_key        = "email"
        projection_type = "ALL"
      },
      {
        name            = "StatusCreatedIndex"
        hash_key        = "status"
        range_key       = "createdAt"
        projection_type = "INCLUDE"
        non_key_attributes = ["userId", "email"]
      }
    ]
    EOF

    terraform apply
    ```
  - Deploy con DynamoDB Streams per event-driven architecture
    ```bash
    # Streams per trigger Lambda
    terraform apply \
      -var="table_name=orders-table" \
      -var="stream_enabled=true" \
      -var="stream_view_type=NEW_AND_OLD_IMAGES"

    # Stream types disponibili:
    # - KEYS_ONLY: Solo chiavi modificate
    # - NEW_IMAGE: Nuovo stato item
    # - OLD_IMAGE: Vecchio stato item  
    # - NEW_AND_OLD_IMAGES: Entrambi (raccomandato)

    # Recupera Stream ARN per Lambda trigger
    terraform output stream_arn
    ```
  - Deploy con TTL per auto-cleanup
    ```bash
    # TTL per sessioni temporanee o cache
    terraform apply \
      -var="table_name=sessions-table" \
      -var="ttl_enabled=true" \
      -var="ttl_attribute_name=expiresAt"

    # Gli item con timestamp expiresAt passato vengono eliminati automaticamente
    # (entro 48 ore dalla scadenza)
    ```
  - Deploy Global Table multi-region
    ```bash
    # Active-Active replication tra regioni
    terraform apply \
      -var="table_name=my-global-table" \
      -var='replica_regions=["eu-west-1", "us-east-1", "ap-southeast-1"]' \
      -var="billing_mode=PAY_PER_REQUEST"

    # Note:
    # - Global Tables richiedono PITR abilitato
    # - Streams vengono abilitati automaticamente
    # - Last-Writer-Wins conflict resolution
    ```
- Deploy e test con S3 Lambda Integration (Event-Driven Architecture)

  ```bash
  # Deploy completo con Lambda trigger da S3
  terraform apply -var="enable_s3_lambda_integration=true"

  # Deploy con tracking eliminazioni
  terraform apply -var="enable_s3_lambda_integration=true" \
    -var="enable_delete_tracking=true"

  # Test: Upload file to S3 (trigger Lambda → save to DynamoDB)
  BUCKET_NAME=$(terraform output -raw s3_bucket_name)
  echo "Test file content" > /tmp/test-file.txt
  aws s3 cp /tmp/test-file.txt s3://$BUCKET_NAME/uploads/test-file.txt

  # Verifica item salvato in DynamoDB
  TABLE_NAME=$(terraform output -raw table_name)
  aws dynamodb scan --table-name $TABLE_NAME --limit 10

  # Visualizza logs Lambda
  LAMBDA_NAME=$(terraform output -raw lambda_function_name)
  aws logs tail /aws/lambda/$LAMBDA_NAME --follow

  # Query file specifico
  aws dynamodb get-item \
    --table-name $TABLE_NAME \
    --key '{"id": {"S": "uploads/test-file.txt"}}'
  ```
- PartiQL queries (SQL-like)
  ```bash
  # SELECT
  aws dynamodb execute-statement --statement "SELECT * FROM \"$TABLE_NAME\" "
  # INSERT
  aws dynamodb execute-statement \
    --statement "INSERT INTO \"$TABLE_NAME\" VALUE {'id':'user999','name':'Test User'}"
  # UPDATE
  aws dynamodb execute-statement \
    --statement "UPDATE \"$TABLE_NAME\" SET age=25 WHERE id='user123'"
  # DELETE
  aws dynamodb execute-statement \
    --statement "DELETE FROM \"$TABLE_NAME\" WHERE id='user123'"
  # Batch execute
  aws dynamodb batch-execute-statement \
    --statements '[
      {"Statement": "SELECT * FROM \"'"$TABLE_NAME"'\" WHERE id=?", "Parameters": [{"S":"user1"}]},
      {"Statement": "SELECT * FROM \"'"$TABLE_NAME"'\" WHERE id=?", "Parameters": [{"S":"user2"}]}
    ]'
  ```
- Export to S3
  ```bash
  # Export tabella completa a S3
  BUCKET_NAME="my-dynamodb-exports"
  aws dynamodb export-table-to-point-in-time \
    --table-arn $(terraform output -raw table_arn) \
    --s3-bucket $BUCKET_NAME \
    --s3-prefix "exports/${TABLE_NAME}/" \
    --export-format DYNAMODB_JSON

  # List exports
  aws dynamodb list-exports

  # Describe export
  EXPORT_ARN=$(aws dynamodb list-exports --table-arn $(terraform output -raw table_arn) --query 'ExportSummaries[0].ExportArn' --output text)
  aws dynamodb describe-export --export-arn $EXPORT_ARN
  ```
- Distruzione risorse
  ```bash
  # ATTENZIONE: Questo elimina PERMANENTEMENTE la tabella e tutti i dati!

  # Svuota bucket S3 se hai abilitato S3 Lambda integration
  BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)
  if [ -n "$BUCKET_NAME" ]; then
    aws s3 rm s3://$BUCKET_NAME --recursive
  fi

  # Destroy con Terraform
  terraform destroy

  # Verifica eliminazione tabella
  TABLE_NAME=$(terraform output -raw table_name 2>/dev/null)
  if [ -n "$TABLE_NAME" ]; then
    aws dynamodb list-tables | grep $TABLE_NAME
  fi
  ```
- Output Terraform: Dopo il deploy, Terraform fornisce questi output utili:
  ```bash
  # Nome tabella
  terraform output table_name

  # ARN tabella
  terraform output table_arn

  # Stream ARN (se abilitato)
  terraform output stream_arn

  # Info complete
  terraform output -json
  ```

## Limitazioni DynamoDB

| Limite | Valore | Note |
|--------|--------|------|
| Max item size | 400 KB | Include attribute names e values |
| Max attribute value size | 400 KB | Singolo attributo |
| Max GSI per table | 20 | - |
| Max LSI per table | 5 | Solo alla creazione |
| Max attributes in projection | 100 | Per GSI/LSI |
| PITR retention | 35 giorni | Point-in-time recovery |
| Batch write items | 25 | Per request |
| Batch get items | 100 | Max 16MB totale |
| Transaction items | 100 | Max 4MB totale |
| Query result size | 1 MB | Prima pagination |
| Scan result size | 1 MB | Prima pagination |
| Max indexes attributes | 100 | Attributi in tutti GSI+LSI |
| Partition throughput | 3000 RCU, 1000 WCU | Per partition |
| Table throughput | Illimitato | In on-demand mode |


## Riferimenti e documentazione

- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/latest/developerguide/)
- [Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Design Patterns](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-general-nosql-design.html)
- [Pricing Calculator](https://aws.amazon.com/dynamodb/pricing/)
- [Capacity Calculator](https://dynobase.dev/dynamodb-capacity-and-pricing-calculator/)
- [Data Modeling](https://www.alexdebrie.com/posts/dynamodb-one-to-many/)
- [Reserved Keywords](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ReservedWords.html)
- [Error Handling](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Programming.Errors.html)
- [CloudWatch Metrics](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/metrics-dimensions.html)


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
