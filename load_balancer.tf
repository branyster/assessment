 resource "azurerm_network_interface_backend_address_pool_association" "example" {
  network_interface_id = element(azurerm_network_interface.example.*.id, count.index)
  ip_configuration_name = "IPConfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
  count = var.num_servers
  
 }

resource "azurerm_public_ip" "example" {
  name                = "PublicIP"
  resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
  location            = data.azurerm_resource_group.terraform-resources-rg.location
  allocation_method   = "Static"
  sku = "Standard"

  tags = {
    environment = "dev"
  }
}

 resource "azurerm_lb" "example" {
   name                = "LoadBalancer"
   location            = data.azurerm_resource_group.terraform-resources-rg.location
   resource_group_name = data.azurerm_resource_group.terraform-resources-rg.name
   sku = "Standard"

   frontend_ip_configuration {
     name                 = "FrontendPublicIP"
     public_ip_address_id = azurerm_public_ip.example.id
   }
 }

  resource "azurerm_lb_backend_address_pool" "example" {
   loadbalancer_id     = azurerm_lb.example.id
   name                = "BackendAddressPool"
 }

 ## Load Balancer Probe ##

 resource "azurerm_lb_probe" "example" {
  name = "tcp-probe"
  protocol = "Tcp"
  port = 443
  loadbalancer_id = azurerm_lb.example.id

  interval_in_seconds = 5

  number_of_probes = 2
   
 }
 
 ## Load Balancer Rule ##

 resource "azurerm_lb_rule" "example" {

  name = "web-https-rule"
  protocol = "Tcp"
  frontend_port = 443
  backend_port = 443
  frontend_ip_configuration_name = azurerm_lb.example.frontend_ip_configuration[0].name
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.example.id]
  probe_id = azurerm_lb_probe.example.id
  loadbalancer_id = azurerm_lb.example.id

   depends_on = [
     azurerm_lb_probe.example
   ]
 }
