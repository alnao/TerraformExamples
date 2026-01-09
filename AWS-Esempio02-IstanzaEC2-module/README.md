# AWS Esempio 02 - Istanza EC2 con Modulo del Registry

Questo esempio mostra come creare un'istanza EC2 utilizzando il **modulo ufficiale** dal Terraform Registry invece di definire direttamente le risorse AWS.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbe causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

## Modulo utilizzato

Questo esempio utilizza il modulo `terraform-aws-modules/ec2-instance/aws` dal Terraform Registry:
- **Repository**: https://github.com/terraform-aws-modules/terraform-aws-ec2-instance
- **Registry**: https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws

## Vantaggi dell'uso dei moduli

1. **Riutilizzabilità**: Il modulo è già testato e utilizzato da migliaia di progetti
2. **Best Practices**: Implementa le migliori pratiche AWS
3. **Manutenzione**: Viene aggiornato dalla community e dai maintainer
4. **Documentazione**: Documentazione completa e esempi
5. **Meno codice**: Riduce la quantità di codice da scrivere e mantenere

## Differenze con l'esempio base (AWS-Esempio02-IstanzaEC2)

| Aspetto | Esempio Base | Esempio con Modulo |
|---------|--------------|-------------------|
| **Definizione risorse** | Risorse definite direttamente | Utilizza il modulo del registry |
| **Codice** | Più verboso | Più conciso |
| **Configurazione** | Manuale di ogni parametro | Configurazione semplificata |
| **Security Group** | Definito manualmente | Definito manualmente (esempio) |
| **Metadata options** | Da configurare manualmente | Configurate dal modulo (IMDSv2) |
| **Outputs** | Definiti manualmente | Esposti dal modulo |

## Risorse create

1. **Security Group** personalizzato con regole per:
   - SSH (porta 22)
   - HTTP (porta 80)
   - HTTPS (porta 443)
   - Tutto il traffico in uscita

2. **Istanza EC2** tramite modulo con:
   - AMI Amazon Linux 2023 (ultima versione disponibile)
   - Tipo di istanza configurabile
   - Volume root con crittografia
   - Metadata options (IMDSv2 obbligatorio)
   - User data per bootstrap (opzionale)
   - IAM instance profile (opzionale)
   - Volumi EBS aggiuntivi (opzionale)

3. **Elastic IP** (opzionale)

## Prerequisiti

- Terraform >= 1.0
- AWS CLI configurato con credenziali valide
- Una key pair AWS esistente (o crearla manualmente)
- VPC e Subnet esistenti (opzionale, altrimenti usa il VPC default)
- Bucket S3 per il backend remoto

## Configurazione

1. Copiare il file di esempio delle variabili:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Modificare `terraform.tfvars` con i propri valori:
   ```hcl
   region        = "eu-central-1"
   instance_name = "mia-istanza-ec2"
   instance_type = "t3.micro"
   key_name      = "mia-chiave-ssh"
   ```

3. (Opzionale) Modificare il backend in `backend.tf` se si utilizza un bucket S3 diverso.

## Utilizzo

1. **Inizializzazione**:
   ```bash
   terraform init
   ```

2. **Pianificazione**:
   ```bash
   terraform plan
   ```

3. **Applicazione**:
   ```bash
   terraform apply
   ```

4. **Connessione all'istanza**:
   ```bash
   # Ottenere l'IP pubblico
   terraform output instance_public_ip
   
   # Connettersi via SSH
   ssh -i /path/to/key.pem ec2-user@<PUBLIC_IP>
   ```

5. **Distruzione**:
   ```bash
   terraform destroy
   ```

## Variabili principali

| Variabile | Descrizione | Default | Obbligatoria |
|-----------|-------------|---------|--------------|
| `region` | Regione AWS | `eu-central-1` | No |
| `instance_name` | Nome dell'istanza | `aws-esempio02-ec2-module` | No |
| `instance_type` | Tipo di istanza | `t3.micro` | No |
| `ami_id` | ID AMI (lasciare vuoto per Amazon Linux 2023) | `""` | No |
| `key_name` | Nome della key pair per SSH | `""` | Sì (per SSH) |
| `vpc_id` | ID del VPC | `""` (usa default) | No |
| `subnet_id` | ID della subnet | `""` (usa default) | No |
| `root_volume_size` | Dimensione del volume root (GB) | `20` | No |
| `create_eip` | Crea un Elastic IP | `false` | No |
| `user_data` | Script di bootstrap | `""` | No |
| `enable_termination_protection` | Protezione dalla terminazione | `false` | No |

## Outputs

- `instance_id`: ID dell'istanza EC2
- `instance_arn`: ARN dell'istanza EC2
- `instance_public_ip`: IP pubblico dell'istanza
- `instance_private_ip`: IP privato dell'istanza
- `instance_public_dns`: DNS pubblico dell'istanza
- `security_group_id`: ID del security group
- `elastic_ip`: IP elastico (se creato)
- `ssh_connection_string`: Comando SSH per connettersi

## Esempio con User Data

Per installare e avviare un web server Apache:

```hcl
user_data = <<-EOF
  #!/bin/bash
  yum update -y
  yum install -y httpd
  systemctl start httpd
  systemctl enable httpd
  echo "<h1>Hello from EC2 Instance!</h1>" > /var/www/html/index.html
EOF
```

## Esempio con volumi EBS aggiuntivi

```hcl
additional_ebs_volumes = [
  {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true
  }
]
```

## Note di sicurezza

⚠️ **IMPORTANTE**:

1. **SSH CIDR Blocks**: L'esempio usa `0.0.0.0/0` per semplicità, ma in produzione limitare l'accesso SSH solo agli IP necessari
2. **Crittografia**: Il volume root è crittografato per default
3. **IMDSv2**: Il modulo configura automaticamente l'instance metadata service v2 per maggiore sicurezza
4. **Termination Protection**: Abilitare `enable_termination_protection = true` per ambienti di produzione

## Costi stimati

Con configurazione di default (t3.micro in eu-central-1):
- Istanza EC2: ~$0.0114/ora (~$8.35/mese)
- Volume EBS gp3 20GB: ~$1.60/mese
- Elastic IP (se allocato ma non associato): $0.005/ora
- Traffico dati: variabile in base all'utilizzo

**Totale stimato**: ~$10/mese

💡 **Tip**: Usa `terraform destroy` quando non utilizzi le risorse per evitare costi inutili.

## Riferimenti

- [Terraform AWS EC2 Instance Module](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws)
- [AWS EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Amazon Linux 2023](https://aws.amazon.com/linux/amazon-linux-2023/)
- [AWS Instance Metadata Service v2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)




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



