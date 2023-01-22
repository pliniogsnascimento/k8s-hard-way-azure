output "tls_cert" {
  value     = tls_private_key.example_ssh.private_key_pem
  sensitive = true
}

output "public_ip_addresses" {
  value = azurerm_linux_virtual_machine.test.*.public_ip_address
}
