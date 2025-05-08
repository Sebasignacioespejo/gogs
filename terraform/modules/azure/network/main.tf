# Rescource Group

resource "azurerm_resource_group" "gogs" {
  name     = "gogs"
  location = "westus"
}

# Virtual Network

resource "azurerm_virtual_network" "main" {
  name                = "gogs-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.gogs.location
  resource_group_name = azurerm_resource_group.gogs.name
}

# Public Subnet

resource "azurerm_subnet" "public_subnet" {
  name                 = "gogs-public-subnet"
  resource_group_name  = azurerm_resource_group.gogs.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Public IP 

resource "azurerm_public_ip" "public_ip" {
  name                = "gogs-public-ip"
  location            = azurerm_resource_group.gogs.location
  resource_group_name = azurerm_resource_group.gogs.name
  allocation_method   = "Static"
}

# Network Interface

resource "azurerm_network_interface" "nic" {
  name                = "gogs-nic"
  location            = azurerm_resource_group.gogs.location
  resource_group_name = azurerm_resource_group.gogs.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

#Private Subnet 1

resource "azurerm_subnet" "private_subnet" {
  name                 = "gogs-private-subnet"
  resource_group_name  = azurerm_resource_group.gogs.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "psql-flexible-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }
}

# Security Groups

# NSG for VM (public)

resource "azurerm_network_security_group" "vm_nsg" {
  name                = "gogs-vm-nsg"
  location            = azurerm_resource_group.gogs.location
  resource_group_name = azurerm_resource_group.gogs.name

  security_rule {
    name                       = "Allow-Port-3000"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH-From-Two-IPs"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = [var.agent_ip, var.control_ip]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-VM-From-DB"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.0.1.0/24" #Private subnet range
    destination_address_prefix = "*"
  }
}

# NSG for DB (private)

resource "azurerm_network_security_group" "db_nsg" {
  name                = "gogs-db-nsg"
  location            = azurerm_resource_group.gogs.location
  resource_group_name = azurerm_resource_group.gogs.name

  security_rule {
    name                       = "Allow-DB-From-VM"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.0.0.0/24" # Public subnet range
    destination_address_prefix = "*"
  }
}

# Associations

resource "azurerm_subnet_network_security_group_association" "public_assoc" {
  subnet_id                 = azurerm_subnet.public_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "private_assoc1" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}
