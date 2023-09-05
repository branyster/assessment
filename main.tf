##  CODE WORKS - N.Branson  22/3/2023

resource "azurerm_resource_group" "example" {
  name     = "terraform-resources-rg"
  location = "West Europe"
# location = "UK South"
}

resource "azurerm_virtual_network" "vnet_auto"{
  name = "tf-vnet"
  address_space = ["10.0.0.0/16"]
  location = "West Europe"
  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
    tags = {
    "CREATED-BY" =  "Nick Branson"
    "DEPARTMENT" = "I&C DevOps"
  }
}
resource "azurerm_network_security_group" "example" {
  name = "NetworkRules"
  location = data.azurerm_resource_group.terraform-resources-rg.location
  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
  security_rule {
    name = "allow443"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "443"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
  tags = {
    "CREATED-BY" = "Nick Branson"
  }


}


## <https://www.terraform.io/docs/providers/azurerm/r/availability_set.html>
resource "azurerm_availability_set" "demo" {
  name                = "example-aset"
  location            = data.azurerm_resource_group.terraform-resources-rg.location
  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
}

## <https://www.terraform.io/docs/providers/azurerm/r/subnet.html> 
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.terraform-resources-rg.name
  virtual_network_name = azurerm_virtual_network.vnet_auto.name
  address_prefixes     = ["10.0.1.0/24"]
}


## <https://www.terraform.io/docs/providers/azurerm/r/network_interface.html>
resource "azurerm_network_interface" "example" {
  count               = var.num_servers
  name                = "acctni${count.index}"
  location            = data.azurerm_resource_group.terraform-resources-rg.location
  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name

  ip_configuration {
    name                          = "IPConfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"

  }
}


resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.example.id
  
}

## <https://www.terraform.io/docs/providers/azurerm/r/windows_virtual_machine.html>
resource "azurerm_windows_virtual_machine" "example" {
  count               = var.num_servers
  name                = "acctvm${count.index}"
  tags                = {
    name              = "demovm"
  }
  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
  location            = data.azurerm_resource_group.terraform-resources-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  availability_set_id = azurerm_availability_set.demo.id
  network_interface_ids = ["${element(azurerm_network_interface.example.*.id, count.index)}"]  

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "vm_extension_install_iis" {
    depends_on = [
      azurerm_windows_virtual_machine.example
    ]
  count = var.num_servers
  name = "vm_extension_install_iis"
  virtual_machine_id = element(azurerm_windows_virtual_machine.example.*.id,count.index)
  publisher = "Microsoft.Compute"
  type = "CustomScriptExtension"
  type_handler_version = "1.8"
  auto_upgrade_minor_version = true

   settings = <<SETTINGS
  {
    "commandToExecute" : "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
  }
  SETTINGS
  tags = {
    "CREATED BY" = "Nick Branson"
  }
}

resource "azurerm_role_assignment" "vm_metrics_reader" {    
scope = element(azurerm_windows_virtual_machine.example.*.id, count.index)
role_definition_name = "Monitoring Reader"
count = var.num_servers
principal_id = "15178b50-4f65-4e43-9648-230e6c26076c"
}

resource "azurerm_role_assignment" "vm_contributor" {
scope = element(azurerm_windows_virtual_machine.example.*.id, count.index)
role_definition_name = "Virtual Machine Contributor"
principal_id = "15178b50-4f65-4e43-9648-230e6c26076c"
count = var.num_servers
}

resource "azurerm_backup_policy_vm" "assessment_backup_policy" {
  name = "nickbranson-sandbox-vault-policy"
  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_backup_vault.name

  timezone = "UTC"
  backup {
    frequency = "Daily"
    time = "23:00"
  }

  retention_daily {
    count = 10
  }

  retention_weekly {
    count = 42
    weekdays = ["Sunday","Wednesday","Friday","Saturday"]
  }

  retention_monthly {
    count = 7
    weekdays = ["Sunday","Wednesday"]
    weeks = ["First","Last"]
  }

  retention_yearly {
    count = 77
    weekdays = ["Sunday"]
    weeks = ["Last"]
    months = ["January"]
  }
}

resource "azurerm_backup_protected_vm" "network_south_vm_backup"{

  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_backup_vault.name
  source_vm_id = element(azurerm_windows_virtual_machine.example.*.id, count.index)
  backup_policy_id = azurerm_backup_policy_vm.assessment_backup_policy.id
  count = var.num_servers
}

resource "azurerm_recovery_services_vault" "vm_backup_vault" {
  name = "nickbranson-sandbox-recovery-vault"
  location = data.azurerm_resource_group.terraform-resources-rg.location
  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
  sku = "Standard"
  soft_delete_enabled = false 

}
