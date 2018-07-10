variable "resourcename" {
  default = "testing_resource_group"
}

# Configure the Microsoft Azure Provider
provider "azurerm" {}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "testingresourcegroup" {
  name     = "${var.resourcename}"
  location = "eastus"

  tags {
    environment = "Testing"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "testing_network" {
  name                = "testingNetwork"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.testingresourcegroup.name}"

  tags {
    environment = "Testing"
  }
}

# Create subnet
resource "azurerm_subnet" "testing_subnet" {
  name                 = "testingSubnet"
  resource_group_name  = "${azurerm_resource_group.testingresourcegroup.name}"
  virtual_network_name = "${azurerm_virtual_network.testing_network.name}"
  address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "testing_pip" {
  name                         = "testingPIP"
  location                     = "eastus"
  resource_group_name          = "${azurerm_resource_group.testingresourcegroup.name}"
  public_ip_address_allocation = "dynamic"

  tags {
    environment = "Testing"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "testing_network_security_group" {
  name                = "testingNetworkSecurityGroup"
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.testingresourcegroup.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "Testing"
  }
}

# Create network interface
resource "azurerm_network_interface" "testing_nic" {
  name                      = "testingNIC"
  location                  = "eastus"
  resource_group_name       = "${azurerm_resource_group.testingresourcegroup.name}"
  network_security_group_id = "${azurerm_network_security_group.testing_network_security_group.id}"

  ip_configuration {
    name                          = "testingNICConfiguration"
    subnet_id                     = "${azurerm_subnet.testing_subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.testing_pip.id}"
  }

  tags {
    environment = "Testing"
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.testingresourcegroup.name}"
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "testing_storage_account" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.testingresourcegroup.name}"
  location                 = "eastus"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags {
    environment = "Testing"
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "testing_vm" {
  name                  = "testingVM"
  location              = "eastus"
  resource_group_name   = "${azurerm_resource_group.testingresourcegroup.name}"
  network_interface_ids = ["${azurerm_network_interface.testing_nic.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "testingVM"
    admin_username = "azureuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNJXOspJHO/HMVOOppagCgtI7hXrV/Q8tYD8X8AXnUs+kdKzh9PixsDkr+mvOF6TIpt5HZRiFzQDYeij5EybUuxzuIIYWZ20uE45uWpnkc58nhGbbIRsNixgzjC+sKFnh1J2cW5MErHPKoihJpx4BQXdA397c39MIhkTa4tlmJTNqotLbLzA9FESavJz1UKeB1QH6clnD832Az0gCdNt//aiFBhR3a5LkItAoMxjda6s6n8JJwwFz8BXPzB7bPNLh6uiwfncvgzLLj7xW2HfVuov6png3h9LNabeaFFnMXI/oF3Bz6oe1JJeNHBFuquof529cqm0u6tP6+e9FYhjqt"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.testing_storage_account.primary_blob_endpoint}"
  }

  tags {
    environment = "Testing"
  }
}
