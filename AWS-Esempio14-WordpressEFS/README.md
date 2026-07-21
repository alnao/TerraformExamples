# AWS Esempio 14 - WordPress con EC2 + EFS + RDS

Questo esempio crea un ambiente WordPress minimale su AWS con Terraform:
- EC2 `t2.micro` con `Elastic IP` pubblico
- Amazon `EFS` montato su `/var/www/html` per persistenza file WordPress
- Amazon `RDS MySQL` con istanza piccola `db.t3.micro`
- Nessun load balancer, nessun autoscaling
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati ⚠️

## Struttura

```
AWS-Esempio14-wordpressEFS/
├── backend.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

## Risorse Create

1. **Networking (default VPC)**
   - Usa la VPC di default
   - Usa le subnet di default

2. **Security Groups**
   - EC2: ingress `22` (SSH) e `80` (HTTP)
   - EFS: ingress `2049` solo da EC2
   - RDS: ingress `3306` solo da EC2

3. **Storage & Database**
   - EFS encrypted con mount target
   - RDS MySQL 8.0 (`db.t3.micro`, single-AZ)

4. **Compute**
   - EC2 `t2.micro`
   - Bootstrap via `user_data`:
     - installa Apache + PHP
     - monta EFS su `/var/www/html`
     - scarica e configura WordPress
   - Elastic IP associato all'istanza

## Prerequisiti

1. Terraform >= 1.0
2. Credenziali AWS configurate
3. Permessi IAM per:
   - EC2
   - EIP
   - EFS
   - RDS
   - VPC/Security Group

## Uso

```bash
cd AWS-Esempio14-wordpressEFS
terraform init
terraform plan
terraform apply
```

Con password DB personalizzata:

```bash
terraform apply -var="db_password=UnaPasswordSicura123!"
```

A deploy completato:

```bash
terraform output wordpress_url
```

Apri l'URL nel browser e completa il setup guidato di WordPress.

## Variabili Principali

| Variabile | Default | Descrizione |
|-----------|---------|-------------|
| `region` | `eu-central-1` | Regione AWS |
| `instance_type` | `t2.micro` | Tipo EC2 |
| `db_instance_class` | `db.t3.micro` | Classe RDS |
| `db_name` | `wordpressdb` | Nome DB |
| `db_username` | `wpadmin` | Utente DB |
| `db_password` | `ChangeMe123!` | Password DB |
| `allowed_ingress_cidr` | `["0.0.0.0/0"]` | CIDR per SSH/HTTP |

## Output

- `wordpress_url`: URL pubblico del sito
- `elastic_ip`: Elastic IP pubblico
- `ec2_instance_id`: ID EC2
- `efs_id`: ID EFS
- `rds_endpoint`: Endpoint RDS

## Costi Stimati (ordine di grandezza)

Stime indicative per `eu-central-1`, uso continuativo 24/7, escluse promo/free tier e tasse.
I costi reali possono variare in base a traffico, storage e ore effettive.

### Configurazione di questo esempio (base)

- EC2 `t2.micro`: ~`$9-12/mese`
- RDS MySQL `db.t3.micro` (single-AZ): ~`$14-20/mese`
- EFS Standard: ~`$0.30/GB/mese` (es. 10 GB => ~$3/mese)
- Elastic IP: ~$0-4/mese (dipende da policy/uso AWS)

Totale tipico laboratorio con 10 GB EFS: ~`$26-39/mese`.

### Scenario con macchine più grandi

Esempi rapidi (sempre single EC2 + single RDS, senza LB/ASG):

| Scenario | EC2 | RDS | Totale compute+DB stimato |
|----------|-----|-----|----------------------------|
| Piccolo (attuale) | `t2.micro` | `db.t3.micro` | `~$23-32/mese` |
| Medio | `t3.small` | `db.t3.small` | `~$45-70/mese` |
| Performance base | `t3.medium` | `db.t3.medium` | `~$80-130/mese` |
| Più robusto | `t3.large` | `db.t3.large` | `~$150-250/mese` |

Da aggiungere a tutti gli scenari:
- EFS (in base ai GB usati)
- Snapshot/backup RDS (se aumenti retention)
- Data transfer Internet (dipende dal traffico del sito)

Suggerimento pratico: per capire il costo reale del tuo caso, avvia con la taglia base 1-2 settimane e misura CPU/RAM/IO prima di scalare.

## Mini-Analisi Evolutiva

Evoluzione consigliata in 4 step, dal lab alla produzione.

1. Stabilizzazione minima
- Restringi `allowed_ingress_cidr` al tuo IP.
- Aggiungi `key_name` e accesso SSH controllato.
- Definisci password DB via variabili sicure (o secret esterno).

2. Affidabilita'
- Passa a RDS con backup retention > 0 e snapshot finali.
- Valuta `db.t3.small` o `db.t3.medium` se il backend e' lento.
- Se prevedi piu' file/media, tieni EFS ma monitora throughput/latenza.

3. Sicurezza e networking
- Sposta EC2 in subnet privata e usa un entrypoint pubblico gestito.
- Introduci HTTPS (ACM + reverse proxy o ALB quando serve).
- Gestisci secret con AWS Secrets Manager e IAM role per EC2.

4. Scalabilita' applicativa
- Migra da singola EC2 a Auto Scaling Group dietro ALB.
- Valuta ElastiCache Redis per object/page cache.
- Per carichi alti, valuta RDS Multi-AZ e/o read replica.

Nota architetturale: il design attuale e' ottimo per test, demo e piccoli siti; il primo collo di bottiglia reale di solito e' il database (CPU/connessioni) prima della parte web.

## Note Sicurezza

Configurazione orientata al test/lab. Per produzione:
- limitare `allowed_ingress_cidr` al proprio IP
- usare password robuste e gestite con AWS Secrets Manager
- introdurre HTTPS, WAF, backup policy e hardening OS

## Cleanup

```bash
terraform destroy
```



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
