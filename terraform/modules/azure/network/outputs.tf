output "rsg_name" {
  value = azurerm_resource_group.gogs.name
}

output "rsg_location" {
  value = azurerm_resource_group.gogs.location
}

output "private_subnet_id" {
  value = azurerm_subnet.private_subnet.id
}

output "nic_id" {
  value = azurerm_network_interface.nic.id
}

output "vm_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}
