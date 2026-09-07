# ====================================
# LA CATENA LOG -> METRICA -> ALLARME -> SNS
#
#   Apache scrive una riga JSON per ogni richiesta
#     -> il CloudWatch Agent la spedisce a questo log group
#       -> i metric filter contano righe totali ed errori
#         -> tre allarmi diversi guardano quelle metriche
#           -> ogni allarme pubblica sul topic SNS
#
# Nota: un metric filter non pubblica nulla quando non trova corrispondenze,
# per questo si usa default_value = 0 e treat_missing_data = "notBreaching".
# ====================================

resource "aws_cloudwatch_log_group" "httpd" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# ---- Filtro 1: conteggio degli errori (metrica senza dimensioni) ----
resource "aws_cloudwatch_log_metric_filter" "http_errors" {
  name           = "${var.project_name}-http-${var.monitored_status_code}"
  log_group_name = aws_cloudwatch_log_group.httpd.name
  pattern        = "{ $.status = ${var.monitored_status_code} }"

  metric_transformation {
    name          = local.metric_errors
    namespace     = local.metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# ---- Filtro 2: totale delle richieste, serve come denominatore del rapporto ----
resource "aws_cloudwatch_log_metric_filter" "http_requests" {
  name           = "${var.project_name}-http-requests"
  log_group_name = aws_cloudwatch_log_group.httpd.name
  pattern        = "{ $.status = * }"

  metric_transformation {
    name          = local.metric_requests
    namespace     = local.metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# ---- Filtro 3: errori suddivisi per path ----
# Le metriche con dimensioni non ammettono default_value: la serie di un path
# esiste solo dai primi errori in poi. E' il prezzo del maggiore dettaglio.
resource "aws_cloudwatch_log_metric_filter" "http_errors_by_path" {
  name           = "${var.project_name}-http-${var.monitored_status_code}-by-path"
  log_group_name = aws_cloudwatch_log_group.httpd.name
  pattern        = "{ $.status = ${var.monitored_status_code} }"

  metric_transformation {
    name       = local.metric_errors_by_path
    namespace  = local.metric_namespace
    value      = "1"
    unit       = "Count"
    dimensions = { Path = "$.path" }
  }
}

# ====================================
# ALLARME 1 - SOGLIA ASSOLUTA
# Il piu' semplice: "piu' di N errori nel periodo".
# ====================================

resource "aws_cloudwatch_metric_alarm" "http_errors" {
  alarm_name          = "${var.project_name}-http-${var.monitored_status_code}"
  alarm_description   = "Numero di risposte HTTP ${var.monitored_status_code} del web server dell'esempio 18"
  namespace           = local.metric_namespace
  metric_name         = local.metric_errors
  statistic           = "Sum"
  period              = var.alarm_period_seconds
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = var.alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.errors.arn]
  ok_actions    = [aws_sns_topic.errors.arn]

  tags = local.common_tags
}

# ====================================
# ALLARME 2 - PERCENTUALE DI ERRORE
#
# Piu' realistico del conteggio assoluto: dieci errori su dieci richieste sono
# un incidente, dieci errori su centomila sono rumore. L'espressione usa IF per
# evitare la divisione per zero quando nel periodo non arriva nessuna richiesta.
# ====================================

resource "aws_cloudwatch_metric_alarm" "http_error_rate" {
  count = var.enable_error_rate_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-http-error-rate"
  alarm_description   = "Percentuale di risposte ${var.monitored_status_code} sul totale delle richieste"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = var.error_rate_threshold
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "e1"
    expression  = "IF(m2 > 0, 100 * m1 / m2, 0)"
    label       = "Percentuale di errori"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      namespace   = local.metric_namespace
      metric_name = local.metric_errors
      period      = var.alarm_period_seconds
      stat        = "Sum"
    }
  }

  metric_query {
    id = "m2"
    metric {
      namespace   = local.metric_namespace
      metric_name = local.metric_requests
      period      = var.alarm_period_seconds
      stat        = "Sum"
    }
  }

  alarm_actions = [aws_sns_topic.errors.arn]
  ok_actions    = [aws_sns_topic.errors.arn]

  tags = local.common_tags
}

# ====================================
# ALLARME 3 - ANOMALY DETECTION
#
# Nessuna soglia fissa: CloudWatch impara l'andamento normale della metrica e
# costruisce una banda di normalita'; l'allarme scatta quando il valore ne esce.
# Attenzione, e' l'allarme meno adatto a una demo veloce: il modello ha bisogno
# di qualche ora di dati prima di essere significativo.
# ====================================

resource "aws_cloudwatch_metric_alarm" "http_errors_anomaly" {
  count = var.enable_anomaly_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-http-${var.monitored_status_code}-anomaly"
  alarm_description   = "Errori HTTP fuori dalla banda di normalita' calcolata da CloudWatch"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "ad1"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1, ${var.anomaly_band_width})"
    label       = "Banda di normalita'"
    return_data = true
  }

  metric_query {
    id          = "m1"
    return_data = true
    metric {
      namespace   = local.metric_namespace
      metric_name = local.metric_errors
      period      = 300
      stat        = "Sum"
    }
  }

  alarm_actions = [aws_sns_topic.errors.arn]
  ok_actions    = [aws_sns_topic.errors.arn]

  tags = local.common_tags
}

# ====================================
# LOGS INSIGHTS - QUERY SALVATE
# Restano nella console sotto "Query salvate", pronte da eseguire.
# ====================================

resource "aws_cloudwatch_query_definition" "per_stato" {
  name            = "${var.project_name}/richieste per stato"
  log_group_names = [aws_cloudwatch_log_group.httpd.name]

  query_string = <<-QUERY
    fields @timestamp, status, path
    | stats count() as richieste by status, path
    | sort richieste desc
  QUERY
}

resource "aws_cloudwatch_query_definition" "solo_errori" {
  name            = "${var.project_name}/dettaglio errori"
  log_group_names = [aws_cloudwatch_log_group.httpd.name]

  query_string = <<-QUERY
    fields @timestamp, remote_ip, method, path, status, agent
    | filter status = ${var.monitored_status_code}
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "errori_per_ip" {
  name            = "${var.project_name}/errori per indirizzo IP"
  log_group_names = [aws_cloudwatch_log_group.httpd.name]

  query_string = <<-QUERY
    fields remote_ip, status
    | filter status >= 400
    | stats count() as errori by remote_ip
    | sort errori desc
    | limit 20
  QUERY
}

# ====================================
# DASHBOARD
# Chiude il cerchio: log, metrica e grafico nella stessa pagina.
# ====================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Richieste totali ed errori ${var.monitored_status_code}"
          region = var.region
          view   = "timeSeries"
          stat   = "Sum"
          period = var.alarm_period_seconds
          metrics = [
            [local.metric_namespace, local.metric_requests, { label = "Richieste" }],
            [local.metric_namespace, local.metric_errors, { label = "Errori ${var.monitored_status_code}" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Percentuale di errore"
          region = var.region
          view   = "timeSeries"
          period = var.alarm_period_seconds
          yAxis  = { left = { min = 0, max = 100 } }
          metrics = [
            [{ expression = "IF(m2 > 0, 100 * m1 / m2, 0)", label = "% errori", id = "e1" }],
            [local.metric_namespace, local.metric_errors, { id = "m1", stat = "Sum", visible = false }],
            [local.metric_namespace, local.metric_requests, { id = "m2", stat = "Sum", visible = false }],
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Ultimi errori dal log Apache"
          region = var.region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.httpd.name}' | fields @timestamp, remote_ip, method, path, status\n| filter status >= 400\n| sort @timestamp desc\n| limit 20"
        }
      },
    ]
  })
}
