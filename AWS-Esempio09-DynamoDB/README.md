# AWS Esempio 09 - DynamoDB

Questo esempio mostra come creare una tabella Amazon DynamoDB con Terraform, includendo configurazioni avanzate come indexes, streams, autoscaling e backup.

## Risorse create

- **DynamoDB Table**: Tabella NoSQL con schema flessibile
- **Global Secondary Indexes (GSI)**: Indici secondari globali
- **Local Secondary Indexes (LSI)**: Indici secondari locali
- **DynamoDB Streams**: Stream per change data capture
- **Point-in-Time Recovery**: Backup continuo
- **Server-Side Encryption**: Cifratura dati
- **TTL**: Time-to-live automatico
- **Autoscaling**: Scaling automatico della capacità (PROVISIONED mode)
- **CloudWatch Alarms**: Allarmi per throttling
- **Global Tables**: Replica multi-region (opzionale)
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio09Dynamo/terraform.tfstate`.

## Prerequisiti

- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)

## Caratteristiche

✅ **Billing flessibile**: On-demand o provisioned  
✅ **Schema-less**: Flessibilità totale sugli attributi  
✅ **Indexes**: GSI e LSI per query efficienti  
✅ **Streams**: Integrazione con Lambda, Kinesis  
✅ **PITR**: Backup continuo ultimi 35 giorni  
✅ **Encryption**: Cifratura automatica at-rest  
✅ **TTL**: Eliminazione automatica record scaduti  
✅ **Autoscaling**: Adattamento automatico al carico  
✅ **Global Tables**: Multi-region active-active  

## Utilizzo

### Inizializzazione

```bash
terraform init
```

### Deploy base (On-Demand)

```bash
terraform apply -var="table_name=my-dynamodb-table"
```

### Deploy con Provisioned mode

```bash
terraform apply \
  -var="table_name=my-dynamodb-table" \
  -var="billing_mode=PROVISIONED" \
  -var="read_capacity=10" \
  -var="write_capacity=5"
```

### Con autoscaling

```bash
terraform apply \
  -var="table_name=my-dynamodb-table" \
  -var="billing_mode=PROVISIONED" \
  -var="read_capacity=5" \
  -var="write_capacity=5" \
  -var="enable_autoscaling=true" \
  -var="autoscaling_read_max_capacity=100" \
  -var="autoscaling_write_max_capacity=50"
```

### Con Global Secondary Index

```hcl
# In terraform.tfvars
additional_attributes = [
  {
    name = "email"
    type = "S"
  },
  {
    name = "created_at"
    type = "N"
  }
]

global_secondary_indexes = [
  {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  },
  {
    name            = "CreatedAtIndex"
    hash_key        = "created_at"
    range_key       = "id"
    projection_type = "INCLUDE"
    non_key_attributes = ["name", "status"]
  }
]
```

### Con DynamoDB Streams

```bash
terraform apply \
  -var="table_name=my-dynamodb-table" \
  -var="stream_enabled=true" \
  -var="stream_view_type=NEW_AND_OLD_IMAGES"
```

### Con TTL

```bash
terraform apply \
  -var="table_name=my-dynamodb-table" \
  -var="ttl_enabled=true" \
  -var="ttl_attribute_name=expires_at"
```

### Global Table (multi-region)

```bash
terraform apply \
  -var="table_name=my-global-table" \
  -var='replica_regions=["eu-west-1", "us-east-1"]'
```

## Operazioni base con AWS CLI

### Inserire un item

```bash
aws dynamodb put-item \
  --table-name my-dynamodb-table \
  --item '{
    "id": {"S": "user123"},
    "name": {"S": "Mario Rossi"},
    "email": {"S": "mario@example.com"},
    "age": {"N": "30"}
  }'
```

### Leggere un item

```bash
aws dynamodb get-item \
  --table-name my-dynamodb-table \
  --key '{"id": {"S": "user123"}}'
```

### Query con indice

```bash
aws dynamodb query \
  --table-name my-dynamodb-table \
  --index-name EmailIndex \
  --key-condition-expression "email = :email" \
  --expression-attribute-values '{":email": {"S": "mario@example.com"}}'
```

### Scan (tutti gli item)

```bash
aws dynamodb scan \
  --table-name my-dynamodb-table \
  --max-items 100
```

### Update item

```bash
aws dynamodb update-item \
  --table-name my-dynamodb-table \
  --key '{"id": {"S": "user123"}}' \
  --update-expression "SET age = :new_age" \
  --expression-attribute-values '{":new_age": {"N": "31"}}'
```

### Delete item

```bash
aws dynamodb delete-item \
  --table-name my-dynamodb-table \
  --key '{"id": {"S": "user123"}}'
```

## Billing Modes

### PAY_PER_REQUEST (On-Demand)
- **Quando usarlo**: Carichi imprevedibili, nuove applicazioni
- **Costi**: $1.25 per milione di Write Request Units, $0.25 per milione di Read Request Units
- **Pro**: No capacity planning, scaling automatico
- **Contro**: Più costoso per carichi costanti

### PROVISIONED
- **Quando usarlo**: Carichi prevedibili e costanti
- **Costi**: $0.00065/ora per RCU, $0.00065/ora per WCU (eu-central-1)
- **Pro**: Più economico per carichi costanti
- **Contro**: Richiede capacity planning

## Costi esempio

### On-Demand
- 1M write requests/mese: $1.25
- 10M read requests/mese: $2.50
- Storage 10 GB: $2.50
- **Totale**: ~$6.25/mese

### Provisioned (10 RCU, 10 WCU)
- Read: 10 RCU × $0.00065 × 730 ore = $4.75
- Write: 10 WCU × $0.00065 × 730 ore = $4.75
- Storage 10 GB: $2.50
- **Totale**: ~$12/mese (ma copre ~260M read e 26M write)

## Indexes Best Practices

### Global Secondary Index (GSI)
- Può avere diverso hash key dalla tabella
- Ha propria capacity (in PROVISIONED mode)
- Può essere aggiunto/rimosso dopo creazione tabella
- Proiezione: ALL, KEYS_ONLY, o INCLUDE

### Local Secondary Index (LSI)
- Stesso hash key della tabella, diverso range key
- Condivide capacity con tabella
- Deve essere definito alla creazione tabella
- Max 5 LSI per tabella

## DynamoDB Streams

Stream types:
- **KEYS_ONLY**: Solo chiavi modificate
- **NEW_IMAGE**: Nuovo stato dell'item
- **OLD_IMAGE**: Vecchio stato dell'item
- **NEW_AND_OLD_IMAGES**: Entrambi gli stati

Use cases:
- Trigger Lambda functions
- Replica in altri sistemi
- Audit log
- Aggregazioni real-time

## TTL (Time To Live)

```bash
# Item con TTL (scade il 1 Jan 2026)
aws dynamodb put-item \
  --table-name my-dynamodb-table \
  --item '{
    "id": {"S": "temp123"},
    "data": {"S": "temporary data"},
    "expires_at": {"N": "1735689600"}
  }'
```

L'item verrà eliminato automaticamente dopo la scadenza.

## Point-in-Time Recovery

```bash
# Restore a un punto nel tempo
aws dynamodb restore-table-to-point-in-time \
  --source-table-name my-dynamodb-table \
  --target-table-name my-dynamodb-table-restored \
  --restore-date-time 2025-10-26T12:00:00Z
```

Retention: Ultimi 35 giorni

## Performance Tips

1. **Design keys correttamente**: Hash key con alta cardinalità
2. **Evitare hot partitions**: Distribuire uniformemente i dati
3. **Usare batch operations**: BatchGetItem, BatchWriteItem
4. **Projection ottimale**: Solo attributi necessari in indexes
5. **Evitare scan**: Usare query con indexes
6. **Pagination**: Usare LastEvaluatedKey per grandi dataset

## Capacity Units

### Read Capacity Unit (RCU)
- 1 RCU = 1 strongly consistent read/sec per item ≤ 4KB
- 1 RCU = 2 eventually consistent read/sec per item ≤ 4KB

### Write Capacity Unit (WCU)
- 1 WCU = 1 write/sec per item ≤ 1KB

Esempi:
- Read 10KB item (strongly): 3 RCU
- Read 10KB item (eventually): 2 RCU
- Write 3KB item: 3 WCU

## Output

- `table_name`: Nome della tabella
- `table_arn`: ARN della tabella
- `table_id`: ID della tabella
- `stream_arn`: ARN dello stream (se abilitato)
- `stream_label`: Label dello stream
- `hash_key`: Nome hash key
- `range_key`: Nome range key
- `billing_mode`: Modalità di billing
- `replica_regions`: Regioni replica

## Troubleshooting

### ProvisionedThroughputExceededException
- Aumentare RCU/WCU
- Abilitare autoscaling
- Passare a On-Demand mode
- Usare exponential backoff nei client

### Hot partition
- Redesign hash key
- Aggiungere suffisso random
- Usare composite key

### Large items
- Item size max: 400KB
- Considerare S3 per dati grandi
- Comprimere dati

### Costi elevati
- Monitorare CloudWatch metrics
- Ottimizzare query
- Ridurre projection size
- Valutare On-Demand vs Provisioned

## Limitazioni

- Max item size: 400 KB
- Max GSI: 20 per tabella
- Max LSI: 5 per tabella
- Max attributes in projection: 100
- PITR retention: 35 giorni
- Batch operations: max 25 items

## Security Best Practices

1. **IAM policies**: Least privilege access
2. **Encryption**: Sempre abilitata
3. **VPC Endpoints**: Per accesso privato
4. **Audit**: CloudTrail logging
5. **Backup**: PITR abilitato
6. **KMS**: Custom CMK per encryption

## Riferimenti

- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/)
- [Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Pricing](https://aws.amazon.com/dynamodb/pricing/)
- [Capacity Calculator](https://dynobase.dev/dynamodb-capacity-and-pricing-calculator/)
