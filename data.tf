data "azurerm_resource_group" "terraform-resources-rg" {
  name = "terraform-resources-rg"

}

data "azurerm_public_ip" "public_ip" {

    name = azurerm_public_ip.example.name
    resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
  
}
