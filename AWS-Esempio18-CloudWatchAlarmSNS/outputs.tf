output "instance_id" {
  description = "ID dell'istanza EC2"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "IP pubblico dell'istanza EC2"
  value       = aws_instance.web.public_ip
}

output "url_ok" {
  description = "URL che risponde 200"
  value       = "http://${aws_instance.web.public_ip}/ok/"
}

output "url_ko" {
  description = "URL che risponde con il codice monitorato"
  value       = "http://${aws_instance.web.public_ip}/ko"
}

output "log_group_name" {
  description = "Log group CloudWatch con gli accessi Apache"
  value       = aws_cloudwatch_log_group.httpd.name
}

output "metric_filter_name" {
  description = "Nome del metric filter che conta gli errori"
  value       = aws_cloudwatch_log_metric_filter.http_errors.name
}

output "alarm_name" {
  description = "Nome dell'allarme CloudWatch"
  value       = aws_cloudwatch_metric_alarm.http_errors.alarm_name
}

output "sns_topic_arn" {
  description = "ARN del topic SNS che riceve le notifiche"
  value       = aws_sns_topic.errors.arn
}

output "url_privata" {
  description = "URL protetto da Basic Auth: 401 senza credenziali, 403 con utente non autorizzato"
  value       = "http://${aws_instance.web.public_ip}/privata/"
}

output "url_storico_allarmi" {
  description = "Pagina web con lo storico degli allarmi letto da DynamoDB"
  value       = "http://${aws_instance.web.public_ip}/allarmi/"
}

output "api_url" {
  description = "Base URL dell'API Gateway (endpoint GET /allarmi)"
  value       = local.api_url
}

output "dynamodb_table_name" {
  description = "Tabella DynamoDB con lo storico degli allarmi"
  value       = aws_dynamodb_table.allarmi.name
}

output "dashboard_url" {
  description = "Dashboard CloudWatch dell'esempio"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "comando_prova" {
  description = "Script che genera il traffico di prova"
  value       = "./traffico.sh -e 10 -o 5"
}
