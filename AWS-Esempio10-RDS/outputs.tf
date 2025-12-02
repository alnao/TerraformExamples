output "cluster_id" {
  description = "ID del cluster Aurora"
  value       = aws_rds_cluster.main.id
}

output "cluster_arn" {
  description = "ARN del cluster Aurora"
  value       = aws_rds_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint del cluster Aurora (write)"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Endpoint read-only del cluster Aurora"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "Porta del cluster"
  value       = aws_rds_cluster.main.port
}

output "cluster_database_name" {
  description = "Nome del database"
  value       = aws_rds_cluster.main.database_name
}

output "cluster_master_username" {
  description = "Username master"
  value       = aws_rds_cluster.main.master_username
  sensitive   = true
}

output "cluster_resource_id" {
  description = "Resource ID del cluster"
  value       = aws_rds_cluster.main.cluster_resource_id
}

output "cluster_hosted_zone_id" {
  description = "Hosted Zone ID del cluster"
  value       = aws_rds_cluster.main.hosted_zone_id
}

output "instance_endpoints" {
  description = "Endpoints delle istanze"
  value       = aws_rds_cluster_instance.main[*].endpoint
}

output "instance_identifiers" {
  description = "ID delle istanze"
  value       = aws_rds_cluster_instance.main[*].identifier
}

output "security_group_id" {
  description = "ID del security group"
  value       = aws_security_group.rds.id
}

output "connection_string" {
  description = "Stringa di connessione MySQL"
  value       = "mysql -h ${aws_rds_cluster.main.endpoint} -P ${aws_rds_cluster.main.port} -u ${aws_rds_cluster.main.master_username} -p ${aws_rds_cluster.main.database_name}"
}

output "connection_details" {
  description = "Dettagli di connessione"
  value = {
    endpoint  = aws_rds_cluster.main.endpoint
    port      = aws_rds_cluster.main.port
    database  = aws_rds_cluster.main.database_name
    username  = aws_rds_cluster.main.master_username
  }
}
