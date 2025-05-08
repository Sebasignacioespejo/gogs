# SSH Key

data "azurerm_ssh_public_key" "gogs_key" {
  name                = var.vm_key_name
  resource_group_name = "gogs-admin"
}


# VM

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "gogs-vm"
  resource_group_name             = var.rsg_name
  location                        = var.rsg_location
  size                            = "Standard_B2ms"
  admin_username                  = "ubuntu"
  disable_password_authentication = true
  network_interface_ids           = [var.nic_id]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = data.azurerm_ssh_public_key.gogs_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
