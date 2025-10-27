output "resource_group_name" {
  description = "Nome del Resource Group"
  value       = azurerm_resource_group.main.name
}

output "vm_id" {
  description = "ID della Virtual Machine"
  value       = azurerm_linux_virtual_machine.main.id
}

output "vm_name" {
  description = "Nome della Virtual Machine"
  value       = azurerm_linux_virtual_machine.main.name
}

output "public_ip_address" {
  description = "Indirizzo IP pubblico della VM"
  value       = var.create_public_ip ? azurerm_public_ip.main[0].ip_address : null
}

output "private_ip_address" {
  description = "Indirizzo IP privato della VM"
  value       = azurerm_network_interface.main.private_ip_address
}

output "admin_username" {
  description = "Username amministratore"
  value       = var.admin_username
}

output "ssh_connection_string" {
  description = "Stringa per connessione SSH"
  value       = var.create_public_ip && var.disable_password_authentication ? "ssh ${var.admin_username}@${azurerm_public_ip.main[0].ip_address}" : "SSH non configurato o IP pubblico non disponibile"
}

output "network_interface_id" {
  description = "ID della Network Interface"
  value       = azurerm_network_interface.main.id
}

output "network_security_group_id" {
  description = "ID del Network Security Group"
  value       = azurerm_network_security_group.main.id
}
