# ====================================
# DYNAMODB
# Una riga per immagine analizzata da Rekognition.
#
# Attributi scritti dalla lambda detect_labels:
#   image_key           (S) chiave S3 completa, es. "input/aereo.jpg"  -> hash key
#   upload_timestamp    (S) data/ora ISO8601 dell'analisi              -> range key del GSI
#   immagine_rilevante  (S) "SI" / "NO"                                -> hash key del GSI
#   labels              (L) lista di mappe { name, confidence }
#   labels_csv          (S) stesse label in formato leggibile
#   keyword             (S) parola chiave usata per la valutazione
#   keyword_confidence  (N) confidenza della label che ha fatto scattare il flag
#   bucket              (S) bucket di provenienza
#   size_bytes          (N) dimensione del file
#
# Nota: immagine_rilevante e' una stringa e non un booleano perche' DynamoDB
# non permette di indicizzare attributi di tipo BOOL.
# ====================================

resource "aws_dynamodb_table" "images" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "image_key"

  attribute {
    name = "image_key"
    type = "S"
  }

  attribute {
    name = "immagine_rilevante"
    type = "S"
  }

  attribute {
    name = "upload_timestamp"
    type = "S"
  }

  # Indice usato dal filtro "solo immagini rilevanti" della pagina web:
  # con la Query si legge solo cio' che serve, senza Scan dell'intera tabella.
  global_secondary_index {
    name            = "RilevanteIndex"
    hash_key        = "immagine_rilevante"
    range_key       = "upload_timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}
