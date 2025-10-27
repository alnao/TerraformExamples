# Azure Esempio 09 - CosmosDB con MongoDB API

Questo esempio mostra come creare un database Azure CosmosDB con API MongoDB usando Terraform, includendo configurazioni avanzate per geo-replication, backup, autoscaling e sicurezza.

## Risorse create

- **Resource Group**: Gruppo di risorse
- **CosmosDB Account**: Account CosmosDB con API MongoDB
- **MongoDB Database**: Database MongoDB
- **MongoDB Collections**: Collections con indexes e sharding
- **Geo-Replication**: (Opzionale) Replica multi-region
- **Backup**: Periodic o Continuous backup
- **Private Endpoint**: (Opzionale) Accesso privato
- **Diagnostic Settings**: (Opzionale) Logging e monitoring

## Prerequisiti

- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva

## Caratteristiche

✅ **MongoDB compatibility**: API compatibile con MongoDB 3.6, 4.0, 4.2  
✅ **Global distribution**: Multi-region attivo-attivo  
✅ **Consistency levels**: 5 livelli configurabili  
✅ **Autoscaling**: RU/s automatico  
✅ **Serverless**: Pay-per-operation (preview)  
✅ **Backup**: Periodic o Continuous  
✅ **Analytical storage**: Synapse Link per analytics  
✅ **Free tier**: 400 RU/s + 5GB gratuiti  
✅ **Zone redundancy**: Alta disponibilità  

## Utilizzo

### Inizializzazione

```bash
terraform init
```

### Deploy base

```bash
terraform apply \
  -var="cosmosdb_account_name=mycosmos123"
```

### Con free tier (400 RU/s gratuiti)

```bash
terraform apply \
  -var="cosmosdb_account_name=mycosmos123" \
  -var="enable_free_tier=true"
```

### Con autoscaling

```bash
terraform apply \
  -var="cosmosdb_account_name=mycosmos123" \
  -var="enable_autoscale=true" \
  -var="autoscale_max_throughput=4000"
```

### Modalità Serverless

```bash
terraform apply \
  -var="cosmosdb_account_name=mycosmos123" \
  -var="enable_serverless=true"
```

### Con geo-replication

```hcl
# In terraform.tfvars
secondary_locations = [
  {
    location          = "North Europe"
    failover_priority = 1
    zone_redundant    = false
  },
  {
    location          = "East US"
    failover_priority = 2
    zone_redundant    = false
  }
]
```

### Multi-master (write in tutte le regioni)

```bash
terraform apply \
  -var="cosmosdb_account_name=mycosmos123" \
  -var="enable_multiple_write_locations=true"
```

### Collection personalizzata

```hcl
# In terraform.tfvars
collections = {
  "products" = {
    shard_key  = "categoryId"
    throughput = 1000
    indexes = [
      {
        keys   = ["_id"]
        unique = true
      },
      {
        keys   = ["sku"]
        unique = true
      },
      {
        keys   = ["name", "price"]
        unique = false
      }
    ]
  }
  "orders" = {
    shard_key           = "customerId"
    enable_autoscale    = true
    max_throughput      = 4000
    default_ttl_seconds = 2592000 # 30 giorni
  }
}
```

## Connessione al database

### Connection string

```bash
# Ottieni connection string
terraform output -raw cosmosdb_connection_strings

# Formato: mongodb://<name>:<key>@<name>.mongo.cosmos.azure.com:10255/?ssl=true
```

### Con mongosh

```bash
mongosh "mongodb://mycosmos123:<PRIMARY_KEY>@mycosmos123.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000"
```

### Node.js

```javascript
const { MongoClient } = require('mongodb');

const connectionString = process.env.COSMOS_CONNECTION_STRING;
const client = new MongoClient(connectionString, {
  useNewUrlParser: true,
  useUnifiedTopology: true
});

async function run() {
  await client.connect();
  const database = client.db('mydb');
  const collection = database.collection('users');
  
  // Insert
  await collection.insertOne({
    userId: "user123",
    name: "Mario Rossi",
    email: "mario@example.com"
  });
  
  // Find
  const user = await collection.findOne({ userId: "user123" });
  console.log(user);
}

run().catch(console.error);
```

### Python

```python
from pymongo import MongoClient

connection_string = "mongodb://..."
client = MongoClient(connection_string)

db = client.mydb
collection = db.users

# Insert
collection.insert_one({
    "userId": "user123",
    "name": "Mario Rossi",
    "email": "mario@example.com"
})

# Find
user = collection.find_one({"userId": "user123"})
print(user)
```

## Consistency Levels

### Eventual
- Migliori performance
- Letture potrebbero non vedere ultime scritture
- Ideale per: social media, IoT telemetry

### Session (Default)
- Consistency per sessione
- Letture vedono proprie scritture
- Ideale per: web applications

### Consistent Prefix
- Letture vedono scritture in ordine
- Nessun gap temporale
- Ideale per: feed ordinati

### Bounded Staleness
- Letture max K versioni o T secondi indietro
- Configurabile
- Ideale per: scoreboards, stock prices

### Strong
- Linearizability garantita
- Performance più basse
- Ideale per: banking, inventory

## Request Units (RU/s)

Operazioni e costi:
- **Read 1KB item**: ~1 RU
- **Write 1KB item**: ~5 RU
- **Query semplice**: ~3 RU
- **Query complessa**: ~10-100 RU
- **Stored procedure**: varia

Esempio calcolo:
- 1M read/giorno = 12 RU/s (media)
- 100K write/giorno = 6 RU/s
- Totale: ~20 RU/s necessari

## Billing Modes

### Provisioned Throughput
- **Costo**: €0.008/ora per 100 RU/s
- **Quando**: Carico prevedibile
- **Storage**: €0.23/GB/mese

### Autoscale
- **Costo**: €0.012/ora per 100 RU/s (max)
- **Quando**: Carico variabile
- **Scale**: 10% di max RU/s al minimo

### Serverless
- **Costo**: €0.25 per milione di RU
- **Quando**: Carico sporadico, dev/test
- **Limiti**: Max 5.000 RU/s, 50GB storage

### Free Tier
- **400 RU/s gratuiti** (provisioned)
- **5 GB storage gratuito**
- **1 account per subscription**

## Costi esempio

### Free Tier
- 400 RU/s: €0
- 5 GB storage: €0
- **Totale**: €0/mese

### Provisioned (400 RU/s)
- Throughput: 400 RU/s × €0.008/100 × 730h = €23.36
- Storage 10 GB: 10 × €0.23 = €2.30
- **Totale**: ~€25.66/mese

### Serverless (10M RU/mese)
- RU: 10 × €0.25 = €2.50
- Storage 5 GB: 5 × €0.23 = €1.15
- **Totale**: ~€3.65/mese

### Multi-region (2 regioni, 400 RU/s)
- Throughput: €23.36 × 2 = €46.72
- Storage: €2.30 × 2 = €4.60
- **Totale**: ~€51.32/mese

## Backup e Recovery

### Periodic Backup
- Intervallo: 1-24 ore
- Retention: 8-720 ore (30 giorni)
- Storage: Geo, Local, Zone redundant
- Restore: Richiede support ticket

### Continuous Backup
- Point-in-time restore
- Retention: 7-30 giorni
- Self-service restore
- Costo: +20% del throughput

```bash
# Restore con Azure CLI
az cosmosdb mongodb database restore \
  --account-name mycosmos123 \
  --name mydb \
  --resource-group rg-cosmos-example \
  --restore-timestamp "2025-10-26T12:00:00Z"
```

## Sharding Best Practices

Shard key ideale:
1. **Alta cardinalità**: Molti valori unici
2. **Distribuzione uniforme**: Evitare hot partitions
3. **Usato in query**: Filtri efficienti
4. **Immutabile**: Non cambia nel tempo

Esempi:
- ✅ `userId`, `customerId`, `orderId`
- ✅ `categoryId` + alto livello di varietà
- ❌ `status` (pochi valori)
- ❌ `createdDate` (concentrazione temporale)

## Indexes

CosmosDB indicizza automaticamente tutti i campi. Puoi personalizzare:

```javascript
// Index policy personalizzata
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [
    { "path": "/name/*" },
    { "path": "/email/*" }
  ],
  "excludedPaths": [
    { "path": "/description/*" }
  ]
}
```

## Performance Tips

1. **Shard key corretto**: Distribuzione uniforme
2. **Indexes ottimizzati**: Solo necessari
3. **Batch operations**: Usare bulkWrite
4. **Connection pooling**: Riutilizzare connessioni
5. **Nearby region**: Client vicini al database
6. **Consistency appropriato**: Session per web apps
7. **Cross-partition queries**: Minimizzare

## Output

- `resource_group_name`: Nome Resource Group
- `cosmosdb_account_id`: ID account CosmosDB
- `cosmosdb_account_name`: Nome account
- `cosmosdb_endpoint`: Endpoint HTTPS
- `cosmosdb_connection_strings`: Connection strings MongoDB (sensibile)
- `cosmosdb_primary_key`: Primary key (sensibile)
- `database_name`: Nome database
- `collection_names`: Lista collections
- `read_endpoints`: Read endpoints per region
- `write_endpoints`: Write endpoints per region

## Troubleshooting

### Request rate too large (429)
- Aumentare RU/s
- Abilitare autoscale
- Ottimizzare query
- Ridurre indexes non necessari

### Slow queries
- Controllare query pattern
- Verificare shard key nelle query
- Controllare index usage
- Usare diagnostic logs

### High costs
- Monitorare RU consumption
- Ottimizzare indexes
- Considerare serverless
- Rivedere consistency level

### Connection timeout
- Verificare firewall rules
- Controllare IP range filter
- Verificare virtual network rules
- Aumentare connection timeout in client

## Limitazioni

- Max 100 collections per database (serverless)
- Max document size: 2 MB
- Max RU/s per partition: 10.000 RU/s
- Serverless max: 5.000 RU/s, 50 GB
- Max regions: 30
- Alcuni MongoDB features non supportati (vedi docs)

## Differenze con DynamoDB

| Feature | CosmosDB Mongo | DynamoDB |
|---------|----------------|----------|
| API | MongoDB | Proprietaria |
| Consistency | 5 livelli | 2 livelli |
| Multi-region | ✅ Nativo | ✅ Global Tables |
| Serverless | ✅ | ✅ |
| Free tier | 400 RU/s + 5GB | 25 GB + 25 RCU/WCU |
| Geo-distribution | Active-Active | Active-Active |
| Max item size | 2 MB | 400 KB |

## Security Best Practices

1. **RBAC**: Usare Azure AD per autenticazione
2. **Keys rotation**: Rotare primary/secondary keys
3. **Private endpoint**: Per accesso interno
4. **IP firewall**: Limitare IP pubblici
5. **Encryption**: Sempre abilitata at-rest
6. **TLS**: Sempre SSL/TLS in connessioni
7. **Monitoring**: Abilitare diagnostic logs

## Riferimenti

- [CosmosDB Documentation](https://docs.microsoft.com/azure/cosmos-db/)
- [MongoDB API Docs](https://docs.microsoft.com/azure/cosmos-db/mongodb/introduction)
- [Pricing Calculator](https://azure.microsoft.com/pricing/details/cosmos-db/)
- [Capacity Planner](https://cosmos.azure.com/capacitycalculator/)
