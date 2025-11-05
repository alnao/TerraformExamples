# AWS Esempio 02 - Istanza EC2
Questo esempio mostra come creare un'istanza EC2 su AWS usando Terraform.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Risorse create**:
- EC2 Instance: Istanza EC2 con Amazon Linux 2023
- Security Group: Gruppo di sicurezza con regole per SSH, HTTP e HTTPS
- Key Pair: (Opzionale) Coppia di chiavi per accesso SSH
- Elastic IP: (Opzionale) IP pubblico statico
- Lo stato remoto viene salvato nel bucket `terraform-aws-alnao` con chiave `Esempio02IstanzaEC2/terraform.tfstate`.

**Prerequisiti**:
- Account AWS con credenziali configurate
- Terraform installato (versione >= 1.0)
- (Opzionale) Coppia di chiavi SSH esistente o generata

**Variabili principali**
- `region`: Regione AWS (default: eu-central-1)
- `instance_name`: Nome dell'istanza EC2
- `instance_type`: Tipo di istanza (default: t3.micro)
- `vpc_id`: ID del VPC (usa default se non specificato)
- `subnet_id`: ID della subnet (usa default se non specificato)

**Output**
- `instance_id`: ID dell'istanza EC2
- `instance_public_ip`: IP pubblico dell'istanza
- `instance_private_ip`: IP privato dell'istanza
- `instance_public_dns`: DNS pubblico dell'istanza
- `security_group_id`: ID del security group
- `elastic_ip`: Elastic IP (se creato)
- `ssh_connection_string`: Stringa per connessione SSH

**Generazione di una coppia di chiavi SSH**
```bash
# Genera una nuova coppia di chiavi
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-ec2-key -N ""

# La chiave pubblica sarà in ~/.ssh/aws-ec2-key.pub
```

## Comandi principali
- Inizializzazione
    ```bash
    terraform init
    ```
- Plan del template
    ```bash
    # Elenco chiavi esistenti
    aws ec2 describe-key-pairs --region eu-central-1 --query 'KeyPairs[*].{Name:KeyName,Id:KeyPairId,Fingerprint:KeyFingerprint}' --output table

    # Con chiave esistente
    terraform plan -var="existing_key_name=alberto-nao-francoforte"

    # Oppure creando una nuova chiave
    terraform plan -var="create_key_pair=true" -var="public_key=$(cat ~/.ssh/aws-ec2-key.pub)"
    ```
- Applicazione
    ```bash
    # Con chiave esistente
    terraform apply -var="existing_key_name=alberto-nao-francoforte"

    # Oppure creando una nuova chiave
    terraform apply -var="create_key_pair=true" -var="public_key=$(cat ~/.ssh/aws-ec2-key.pub)"
    ```
- Esempio con user data (installazione web server)
    ```bash
    terraform apply  -var="existing_key_name=alberto-nao-francoforte" -var="user_data=$(cat <<'EOF'
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from EC2 Instance from terraformexamples/AWS-Esempio02-IstanzaEc2</h1>" > /var/www/html/index.html
    EOF
    )"
    ```
- Connessione all'istanza
    ```bash
    # Dopo il deployment, connettiti via SSH
    ssh -i ~/.ssh/aws-ec2-key ec2-user@<PUBLIC_IP>

    # Il PUBLIC_IP è disponibile nell'output
    terraform output instance_public_ip
    ```
- Distruzione

    ```bash
    terraform destroy
    ```
- Opzioni avanzate
    - Con Elastic IP
        ```bash
        terraform apply -var="create_eip=true"
        ```
    - Con monitoraggio dettagliato
        ```bash
        terraform apply -var="enable_monitoring=true"
        ```
    - Con volume cifrato di dimensioni personalizzate
        ```bash
        terraform apply -var="root_volume_size=50" -var="encrypt_volume=true"
        ```
    - Note di sicurezza
        ⚠️ **IMPORTANTE**: L'esempio di default permette accesso SSH da qualsiasi IP (0.0.0.0/0). In produzione, limitare `ssh_cidr_blocks` agli IP necessari:
        ```bash
        terraform apply -var='ssh_cidr_blocks=["YOUR_IP/32"]'
        ```

## Costi
- Istanza t3.micro: ~$0.0104/ora (~$7.50/mese) nella regione eu-central-1
- EBS gp3 20GB: ~$1.60/mese
- Elastic IP (se allocato ma non associato): ~$3.65/mese
- Trasferimento dati: varia in base all'utilizzo



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



