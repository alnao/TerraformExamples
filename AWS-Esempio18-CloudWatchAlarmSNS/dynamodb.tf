# ====================================
# DYNAMODB - STORICO DEGLI ALLARMI
#
# Chiave composta: partizione = nome dell'allarme, ordinamento = istante del
# cambio di stato. Cosi' la Query "ultimi eventi di un allarme" e' immediata.
# Il TTL cancella da solo le righe piu' vecchie di ttl_days.
# ====================================

resource "aws_dynamodb_table" "allarmi" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "alarm_name"
  range_key    = "timestamp"

  attribute {
    name = "alarm_name"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = local.common_tags
}
