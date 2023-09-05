output "ip" {
  value = "${data.azurerm_public_ip.public_ip.ip_address}"
}