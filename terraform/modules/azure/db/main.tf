# Private DNS

resource "azurerm_private_dns_zone" "db_private_dns" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.rsg_name
}

# VNET-DNS Link

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "private-dns-link"
  resource_group_name   = var.rsg_name
  private_dns_zone_name = azurerm_private_dns_zone.db_private_dns.name
  virtual_network_id    = var.vnet_id
}

# DB Instance

resource "azurerm_postgresql_flexible_server" "gogs_db" {
  name                   = "gogs-db"
  location               = var.rsg_location
  resource_group_name    = var.rsg_name
  administrator_login    = var.db_user
  administrator_password = var.db_password

  version                       = "13"
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  public_network_access_enabled = false

  delegated_subnet_id = var.private_subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.db_private_dns.id
}

# DB Declaration

resource "azurerm_postgresql_flexible_server_database" "gogs_db" {
  name      = "gogs"
  server_id = azurerm_postgresql_flexible_server.gogs_db.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}
