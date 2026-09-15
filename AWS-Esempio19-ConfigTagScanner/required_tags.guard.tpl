# Regola custom (CloudFormation Guard) per i tag obbligatori.
# Generata da Terraform da required_tag_keys e allowed_tag_values: NON modificare a mano.
#
# Config passa alla policy il configuration item della risorsa: "tags" e' la
# mappa dei tag registrati. Ogni clausola che fallisce rende la risorsa
# NON_COMPLIANT, con il messaggio fra << >> come annotazione.
# Con tag_keys_case_insensitive ogni chiave e' accettata anche come
# Project / PROJECT: le varianti sono in OR sulla stessa riga.
rule tag_obbligatori {
%{ for chiave, varianti in chiavi ~}
    ${join(" OR ", [for v in varianti : "tags.${v} exists"])} <<manca il tag ${chiave}>>
%{ endfor ~}
%{ for chiave, varianti in chiavi ~}
%{ if contains(keys(allowed_values), chiave) ~}
    ${join(" OR ", [for v in varianti : "tags.${v} IN [${join(", ", [for x in allowed_values[chiave] : "\"${x}\""])}]"])} <<${chiave} deve essere uno fra ${join(", ", allowed_values[chiave])}>>
%{ endif ~}
%{ endfor ~}
}
