# Azure Esempio 02 - Istanze VM (Virtual Machine)

Questo esempio mostra come creare una Virtual Machine Linux su Azure usando Terraform.
- ⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️

**Risorse create**:
- Resource Group: Gruppo di risorse per organizzare le risorse
- Virtual Network: Rete virtuale con subnet
- Public IP: (Opzionale) Indirizzo IP pubblico statico
- Network Security Group**: Gruppo di sicurezza con regole per SSH, HTTP e HTTPS
- Network Interface: Interfaccia di rete per la VM
- Linux Virtual Machine: VM Linux con Ubuntu 22.04 LTS
- Storage Account: (Opzionale) Per boot diagnostics
- Managed Disk: (Opzionale) Disco dati aggiuntivo

Nota: lo stato remoto degli esempi viene salvato nello storage-container `alnaoterraformstorage`, modificare il file `backend.tf` per personalizzare questa configurazione.

**Prerequisiti**
- Azure CLI installato e configurato (`az login`)
- Terraform installato (versione >= 1.0)
- Subscription Azure attiva
- (Opzionale) Coppia di chiavi SSH

**Variabili principali**
- `location`: Regione Azure (default: West Europe)
- `vm_name`: Nome della VM
- `vm_size`: Dimensione della VM (default: Standard_B1s - equivalente a t3.micro AWS)
- `admin_username`: Username amministratore (default: azureuser)


**Costi stimati** (West Europe)
⚠️ Nota importante: l'esecuzione di questi esempi nel cloud potrebbero causare costi indesiderati, prestare attanzione prima di eseguire qualsiasi comando ⚠️
- VM Standard_B1s: ~€7.30/mese (1 vCPU, 1 GB RAM)
    | Dimensione | vCPU | RAM | Disco Temp | Costo/mese |
    |------------|------|-----|------------|------------|
    | Standard_B1s | 1 | 1 GB | 4 GB | ~€7.30 |
    | Standard_B2s | 2 | 4 GB | 8 GB | ~€29.20 |
    | Standard_D2s_v3 | 2 | 8 GB | 16 GB | ~€70.08 |
    | Standard_D4s_v3 | 4 | 16 GB | 32 GB | ~€140.16 |
    - Verificare le dimensioni di VM disponibili con i comandi:
        ```bash
        az vm list-skus --location westeurope --resource-type virtualMachines --zone --all --output table | grep -E "Standard_[AB]"
        az vm list-sizes --location westeurope --output table | grep -E "Standard_[AB]"
        az vm list-skus --location westeurope --size Standard_B1s --output table 2>/dev/null | head -20
        ```
- OS Disk Standard_LRS 30GB: ~€1.20/mese
- Public IP Standard Static: ~€2.92/mese
- Storage per boot diagnostics: ~€0.10/mese
- Network egress: varia in base all'utilizzo
- **Totale stimato**: ~€11.50/mese


**Generazione di una coppia di chiavi SSH**
```bash
# Genera una nuova coppia di chiavi
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure-vm-key -N ""
# La chiave pubblica sarà in ~/.ssh/azure-vm-key.pub
```

## Output
- `resource_group_name`: Nome del Resource Group
- `vm_id`: ID della Virtual Machine
- `vm_name`: Nome della VM
- `public_ip_address`: IP pubblico
- `private_ip_address`: IP privato
- `admin_username`: Username amministratore
- `ssh_connection_string`: Stringa per connessione SSH
- `network_interface_id`: ID della Network Interface
- `network_security_group_id`: ID del NSG


## Comandi
- Inizializzazione
    ```bash
    terraform init
    ```
- Pianificazione
    ```bash
    # Con SSH key
    terraform plan -var="ssh_public_key=$(cat ~/.ssh/azure-vm-key.pub)"

    # Con password (meno sicuro)
    terraform plan -var="disable_password_authentication=false" -var="admin_password=YourStrongPassword123!"
    ```
- Applicazione
    ```bash
    # Con SSH key (raccomandato)
    terraform apply -var="ssh_public_key=$(cat ~/.ssh/azure-vm-key.pub)"

    # Con password
    terraform apply -var="disable_password_authentication=false" -var="admin_password=YourStrongPassword123!"
    ```
- Esempio con custom data (installazione web server)
    - Creare un file `cloud-init.txt`:
        ```bash
        #!/bin/bash
        apt-get update
        apt-get install -y nginx
        systemctl start nginx
        systemctl enable nginx
        echo "<h1>Hello from Azure VM</h1>" > /var/www/html/index.html
        ```
    - Applicare con:
        ```bash
        terraform apply \
        -var="ssh_public_key=$(cat ~/.ssh/azure-vm-key.pub)" \
        -var="custom_data=$(cat cloud-init.txt)"
        ```
- Connessione alla VM
    ```bash
    # Dopo il deployment, connettiti via SSH
    ssh -i ~/.ssh/azure-vm-key azureuser@<PUBLIC_IP>

    # Il PUBLIC_IP è disponibile nell'output
    terraform output public_ip_address
    ```
- Distruzione (con chiave fittizia se serve!)
    ```bash
    ssh-keygen -t rsa -b 2048 -f /tmp/temp_azure_key -N "" -C "temp@destroy" && cat /tmp/temp_azure_key.pub
    terraform destroy -var="ssh_public_key=$(cat /tmp/temp_azure_key.pub)" -auto-approve
    ```
- Opzioni avanzate
    - Con disco dati aggiuntivo
        ```bash
        terraform apply \
        -var="ssh_public_key=$(cat ~/.ssh/azure-vm-key.pub)" \
        -var="create_data_disk=true" \
        -var="data_disk_size_gb=100"
        ```
    - Con IP pubblico statico e Premium SSD
        ```bash
        terraform apply \
        -var="ssh_public_key=$(cat ~/.ssh/azure-vm-key.pub)" \
        -var="os_disk_storage_account_type=Premium_LRS" \
        -var="public_ip_allocation_method=Static"
        ```
    - VM di dimensioni maggiori
        ```bash
        # Standard_D2s_v3 (2 vCPU, 8 GB RAM)
        terraform apply \
        -var="ssh_public_key=$(cat ~/.ssh/azure-vm-key.pub)" \
        -var="vm_size=Standard_D2s_v3"
        ```
- Note di sicurezza: ⚠️ **IMPORTANTE**: L'esempio di default permette accesso SSH da qualsiasi IP (0.0.0.0/0). In produzione, limitare `ssh_source_addresses`:
    ```bash
    terraform apply \
    -var="ssh_public_key=$(cat ~/.ssh/azure-vm-key.pub)" \
    -var='ssh_source_addresses=["YOUR_IP/32"]'
    ```


## Immagini Linux supportate
- Ubuntu
    ```hcl
    image_publisher = "Canonical"
    image_offer     = "0001-com-ubuntu-server-jammy"
    image_sku       = "22_04-lts-gen2"
    ```
- CentOS Stream
    ```hcl
    image_publisher = "OpenLogic"
    image_offer     = "CentOS"
    image_sku       = "8_5-gen2"
    ```
- Red Hat Enterprise Linux
    ```hcl
    image_publisher = "RedHat"
    image_offer     = "RHEL"
    image_sku       = "8-lvm-gen2"
    ```
- Debian
    ```hcl
    image_publisher = "Debian"
    image_offer     = "debian-11"
    image_sku       = "11-gen2"
    ```


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



