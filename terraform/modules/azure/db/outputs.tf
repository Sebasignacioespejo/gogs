output "db_endpoint" {
  value = azurerm_postgresql_flexible_server.gogs_db.fqdn
}
