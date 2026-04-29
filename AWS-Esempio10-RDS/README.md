# AWS Esempio 10 - RDS Aurora MySQL

Questo esempio mostra come creare un cluster **Amazon Aurora MySQL** con Terraform, configurato per essere accessibile dal proprio PC.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati ⚠️


## Caratteristiche

- **Aurora MySQL 8.0** - Ultima versione compatibile con MySQL
- **Istanza piccola** - `db.t3.medium` per minimizzare i costi
- **Accesso pubblico** - Configurato per consentire connessioni dal tuo PC
- **Security Group personalizzato** - Aperto a tutti gli IP per semplicità (modificabile)
- **Backup automatici** - Retention di 7 giorni
- **CloudWatch Logs** - Audit, error, general e slow query logs
- **Parameter Groups personalizzati** - Per cluster e istanze
- **Enhanced Monitoring opzionale** - Monitoraggio avanzato
- **Performance Insights opzionale** - Analisi delle performance
- **CloudWatch Alarms opzionali** - Notifiche su CPU, connessioni e memoria

## Struttura

```
AWS-Esempio10-RDS/
├── backend.tf          # Configurazione S3 backend
├── main.tf             # Risorse principali
├── variables.tf        # Variabili configurabili
├── outputs.tf          # Output utili
└── README.md           # Questa documentazione
```

## Prerequisiti

1. AWS CLI configurato
2. Terraform >= 1.0
3. Credenziali AWS con permessi per:
   - RDS
   - VPC
   - Security Groups
   - IAM (per Enhanced Monitoring)
   - CloudWatch

## Risorse Create

1. **VPC e Networking**
   - Usa la VPC di default
   - Subnet group con tutte le subnet disponibili
   - Security group con ingress sulla porta 3306

2. **Aurora Cluster**
   - Cluster Aurora MySQL 8.0
   - 1 istanza `db.t3.medium` (configurabile)
   - Storage encrypted
   - Backup retention 7 giorni

3. **Parameter Groups**
   - Cluster parameter group (charset, collation, max_connections)
   - Instance parameter group (slow query log)

4. **CloudWatch**
   - Log groups per audit, error, general, slowquery
   - Alarms opzionali per CPU, connessioni, memoria

5. **IAM**
   - Role per Enhanced Monitoring (se abilitato)

## Configurazione

### Variabili Principali

```hcl
# Identificatore del cluster
cluster_identifier = "alnao-dev-terraform-esempio10-aurora"

# Credenziali (CAMBIALE IN PRODUZIONE!)
master_username = "alnao"
master_password = "Bellissimo123!"

# Classe istanza (più piccola disponibile)
instance_class = "db.t3.medium"

# Accesso pubblico
publicly_accessible = true
allowed_cidr_blocks = ["0.0.0.0/0"]  # Modifica per limitare l'accesso
```

### Personalizzazione Accesso
- Inizializzazione e pianificazione
   ```bash
   cd AWS-Esempio10-RDS
   terraform init
   terraform plan
   ```
- Applicazione
   ```bash
   # Con password di default (NON per produzione)
   terraform apply

   # Con password personalizzata
   terraform apply -var="master_password=TuaPasswordSicura123!"
   ```
- Connessione al Database
   ```bash
   terraform output cluster_endpoint
   terraform output connection_string
   RDS_ENDPOINT=$(terraform output -raw cluster_endpoint)
   mysql -h $RDS_ENDPOINT -P 3306 --skip-ssl -u alnao -p

   # Oppure usa il connection string fornito in output:
   terraform output -raw connection_string
   ```

   ```sql
   -- Mostra database
   SHOW DATABASES;
   -- Usa il database
   USE esempio10db;

   -- Crea una tabella di test
   CREATE TABLE test (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );

   -- Inserisci dati
   INSERT INTO test (name) VALUES ('Test 1'), ('Test 2');

   -- Query di test
   SELECT * FROM test;
   ```

- Pulizia
   ```bash
   terraform destroy
   ```

## Variabili Configurabili

Vedi `variables.tf` per tutte le opzioni. Principali:

| Variabile | Default | Descrizione |
|-----------|---------|-------------|
| `region` | `eu-central-1` | Regione AWS |
| `cluster_identifier` | `alnao-dev-terraform-esempio10-aurora` | Nome cluster |
| `engine` | `aurora-mysql` | Engine database |
| `engine_version` | `8.0.mysql_aurora.3.04.0` | Versione engine |
| `database_name` | `esempio10db` | Nome database |
| `master_username` | `admin` | Username master |
| `master_password` | `ChangeMe123!` | Password master |
| `instance_class` | `db.t3.medium` | Classe istanza |
| `instance_count` | `1` | Numero istanze |
| `publicly_accessible` | `true` | Accesso pubblico |
| `allowed_cidr_blocks` | `["0.0.0.0/0"]` | CIDR autorizzati |
| `backup_retention_period` | `7` | Giorni retention backup |
| `deletion_protection` | `false` | Protezione cancellazione |
| `enable_performance_insights` | `false` | Performance Insights |
| `enable_cloudwatch_alarms` | `false` | CloudWatch alarms |

## Output Disponibili

```bash
# Endpoint write
terraform output cluster_endpoint

# Endpoint read-only
terraform output cluster_reader_endpoint

# Connection string
terraform output connection_string

# Tutti i dettagli
terraform output connection_details
```

## Sicurezza

⚠️ **IMPORTANTE PER PRODUZIONE:**

1. **Password**: Non usare password hardcoded
   ```hcl
   # Usa AWS Secrets Manager
   data "aws_secretsmanager_secret_version" "db_password" {
     secret_id = "rds/master/password"
   }
   ```

2. **Accesso Pubblico**: Evita `publicly_accessible = true`
   - Usa VPN o bastion host
   - Limita `allowed_cidr_blocks` al tuo IP

3. **Encryption**: Usa KMS key personalizzata
   ```hcl
   storage_encrypted = true
   kms_key_id = aws_kms_key.rds.arn
   ```

4. **Deletion Protection**: Abilita in produzione
   ```hcl
   deletion_protection = true
   skip_final_snapshot = false
   ```

5. **Monitoring**: Abilita Enhanced Monitoring e Performance Insights
   ```hcl
   monitoring_interval = 60
   enable_performance_insights = true
   ```

## Costi Stimati

Per `db.t3.medium` in `eu-central-1`:
- **Istanza**: ~$0.114/ora (~$83/mese per 1 istanza)
- **Storage**: $0.10/GB-mese (primo GB gratis, poi cresce dinamicamente)
- **I/O**: $0.20 per milione di richieste
- **Backup**: $0.021/GB-mese (oltre il retention period)

**Totale stimato**: ~$85-100/mese per utilizzo di sviluppo

💡 **Per minimizzare i costi:**
- Usa solo 1 istanza (`instance_count = 1`)
- Limita `backup_retention_period`
- Usa Aurora Serverless v2 se il carico è variabile
- Ferma il cluster quando non serve (tramite console)

## Troubleshooting

### Non riesco a connettermi

1. Verifica il security group:
   ```bash
   aws ec2 describe-security-groups --group-ids <security_group_id>
   ```

2. Controlla il tuo IP pubblico:
   ```bash
   curl https://api.ipify.org
   ```

3. Testa la connettività:
   ```bash
   telnet <endpoint> 3306
   nc -zv <endpoint> 3306
   ```

4. Verifica che `publicly_accessible = true`

### Errore "password authentication failed"

- Controlla username e password
- Verifica che il cluster sia in stato `available`
- Aspetta qualche minuto dopo la creazione

### Errore di subnet

Aurora richiede almeno 2 subnet in AZ diverse. Il codice usa automaticamente tutte le subnet della VPC default.

## Best Practices

1. **Backup**: Configura backup automatici e testa il restore
2. **Monitoring**: Abilita CloudWatch Logs e alarms
3. **Upgrade**: Pianifica gli upgrade durante le maintenance window
4. **Scaling**: Monitora le metriche e scala quando necessario
5. **Tags**: Usa tag consistenti per gestire le risorse

## Risorse Utili

- [Aurora MySQL Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraMySQL.html)
- [Aurora Pricing](https://aws.amazon.com/rds/aurora/pricing/)
- [Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.BestPractices.html)
- [Parameter Groups](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/USER_WorkingWithParamGroups.html)

## Note

- Il cluster è configurato per ambiente di sviluppo/test
- Per produzione, segui le best practices di sicurezza
- Monitora i costi tramite AWS Cost Explorer
- Considera Aurora Serverless v2 per carichi variabili
- Le password devono rispettare i requisiti AWS (8-41 caratteri, no @/"/)



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
