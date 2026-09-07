#!/bin/bash
# ============================================================
# Esempio 18 - bootstrap del web server
#
#   1. installa Apache e il CloudWatch Agent
#   2. pubblica quattro url:
#        /ok        -> 200
#        /ko        -> ${ko_status_code}   (errore "finto", con Redirect)
#        /privata   -> 401 senza credenziali, 200 con l'utente autorizzato,
#                      403 con un utente valido ma non autorizzato
#        /allarmi   -> pagina che legge lo storico da API Gateway
#   3. scrive gli accessi in formato JSON su un log dedicato
#   4. spedisce quel log al log group CloudWatch ${log_group_name}
# ============================================================
set -euxo pipefail

dnf install -y httpd httpd-tools amazon-cloudwatch-agent

# ---- /ok : pagina normale, risposta 200 ----
mkdir -p /var/www/html/ok
cat > /var/www/html/ok/index.html <<'HTML'
<!doctype html>
<html lang="it">
  <head><meta charset="utf-8"><title>OK</title></head>
  <body style="font-family:sans-serif">
    <h1>200 OK</h1>
    <p>Questa pagina risponde correttamente: non genera nessun allarme.</p>
    <ul>
      <li><a href="/ko">/ko</a> - risposta ${ko_status_code} simulata</li>
      <li><a href="/privata/">/privata</a> - 401 o 403 a seconda delle credenziali</li>
      <li><a href="/allarmi/">/allarmi</a> - storico degli allarmi da DynamoDB</li>
    </ul>
  </body>
</html>
HTML

# ---- pagina di errore mostrata al posto della risposta di default ----
cat > /var/www/html/errore.html <<'HTML'
<!doctype html>
<html lang="it">
  <head><meta charset="utf-8"><title>KO</title></head>
  <body style="font-family:sans-serif">
    <h1>Accesso negato</h1>
    <p>Questa richiesta e' stata rifiutata: finisce nei log, nella metrica e nell'allarme.</p>
    <p><a href="/ok/">torna a /ok</a> &middot; <a href="/allarmi/">storico allarmi</a></p>
  </body>
</html>
HTML

# ---- /privata : autenticazione vera, per vedere la differenza fra 401 e 403 ----
# Due utenti nello stesso file: solo il primo compare nella direttiva Require,
# quindi il secondo si autentica (401 superato) ma non e' autorizzato (403).
mkdir -p /var/www/html/privata
htpasswd -bc /etc/httpd/.htpasswd '${auth_user}' '${auth_password}'
htpasswd -b  /etc/httpd/.htpasswd '${auth_user_bloccato}' '${auth_password_bloccato}'
chown apache:apache /etc/httpd/.htpasswd
chmod 640 /etc/httpd/.htpasswd

cat > /var/www/html/privata/index.html <<'HTML'
<!doctype html>
<html lang="it">
  <head><meta charset="utf-8"><title>Area privata</title></head>
  <body style="font-family:sans-serif">
    <h1>Area privata</h1>
    <p>Autenticato e autorizzato: questa e' la risposta 200.</p>
  </body>
</html>
HTML

# ---- /allarmi : pagina che legge lo storico dall'API Gateway ----
mkdir -p /var/www/html/allarmi
cat > /var/www/html/allarmi/index.html <<'HTML'
${pagina_allarmi}
HTML

# ---- configurazione del sito ----
cat > /etc/httpd/conf.d/sito.conf <<'CONF'
DirectoryIndex index.html

# Un Redirect con un codice diverso da 3xx non fa un vero redirect:
# Apache restituisce direttamente quello stato. E' l'errore "finto" della demo.
Redirect ${ko_status_code} /ko
ErrorDocument ${ko_status_code} /errore.html

RedirectMatch 302 ^/$ /ok/

# Errore "vero": senza credenziali Apache risponde 401 (chi sei?), con
# credenziali valide ma utente non elencato risponde 403 (so chi sei, ma no).
<Directory "/var/www/html/privata">
    AuthType Basic
    AuthName "Area privata esempio 18"
    AuthUserFile /etc/httpd/.htpasswd
    Require user ${auth_user}
</Directory>

# Log applicativo in JSON: un oggetto per riga, cosi' il metric filter
# di CloudWatch puo' leggere il campo "status" senza espressioni fragili.
LogFormat "{\"time\":\"%%{%Y-%m-%dT%H:%M:%S%z}t\",\"remote_ip\":\"%a\",\"method\":\"%m\",\"path\":\"%U\",\"status\":%>s,\"bytes\":%B,\"referer\":\"%%{Referer}i\",\"agent\":\"%%{User-Agent}i\"}" json
CustomLog /var/log/httpd/access_json.log json
CONF

systemctl enable --now httpd

# ---- CloudWatch Agent: spedisce il log JSON al log group ----
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONF'
{
  "agent": {
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_json.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/access",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/error",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWCONF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
