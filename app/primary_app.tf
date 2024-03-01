

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#        VIRTUAL MACHINE                                       #
#                                                              #

resource "azurerm_windows_virtual_machine" "primary_app" {
  count = var.primary_app_count
  name = "${var.datacenter}${var.environment}pa${count.index+1}${random_id.primary_app[count.index].hex}"
  location = azurerm_resource_group.pmxapp_rg.location
  resource_group_name = azurerm_resource_group.pmxapp_rg.name

  admin_username = var.admin_username
  admin_password = data.azurerm_key_vault_secret.pmx_syscredsecret.value

  network_interface_ids = [ 
    azurerm_network_interface.primary_app[count.index].id
  ]

  computer_name = "${var.datacenter}${var.environment}pa${count.index+1}${random_id.primary_app[count.index].hex}"

  os_disk {
    name                 = "${var.datacenter}${var.environment}${random_id.primary_app[count.index].hex}-os"
    disk_size_gb         = 128 #adding 64 to install pmx on C:\
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  
  size = "Standard_D2s_v4"

  # source_image_reference {
  #   publisher = "MicrosoftWindowsServer"
  #   offer     = "WindowsServer"
  #   sku       = "2016-Datacenter-smalldisk"
  #   version   = "latest"
  # }

  source_image_id =  data.azurerm_shared_image_version.pmx-app-image.id

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.environment_identity.id]
  }

  tags = merge(
    local.tags,
    {
      Role                 = "PMX_Primary_App"
      PackageName          = var.force_update_package_name == "" ? var.package_name : var.force_update_package_name
      PackageVersion       = var.force_update_package_version == "" ? var.package_version : var.force_update_package_version
      UpdateGroup          = count.index == 1 ? 1 : 2
      Alias                = local.pa_alias_tag
      ConfigStorageAccount = azurerm_storage_account.pmxapp_storageaccount.name
    }
  )
}
#                                                              #
#        END  VIRTUAL MACHINE                                  #
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# #                     setting table entity                     #
# #                                                              #

resource "azurerm_storage_table_entity" "primaryappsetting_entity" {
  storage_account_name = azurerm_storage_account.pmxapp_storageaccount.name
  table_name           = azurerm_storage_table.configsettings_table.name

  partition_key = "PrimaryApp"
  row_key       = var.LongEnvironmentName

  entity = {
    value     = azurerm_windows_virtual_machine.primary_app[0].computer_name
  }
}

# #                                                              #
# #                    END setting table entity                  #
# # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# #                     Data DISKS                               #
# #                                                              #

# resource "azurerm_managed_disk" "primary_app" {
#   count = var.primary_app_count
#   name = "${azurerm_windows_virtual_machine.primary_app[count.index].name}-data"
#   location = azurerm_resource_group.pmxapp_rg.location
#   resource_group_name = azurerm_resource_group.pmxapp_rg.name

#   storage_account_type = "StandardSSD_LRS"
#   create_option = "Empty"
#   disk_size_gb = 16

#   tags = merge(
#     local.common_tags
#   )
# }

# #                                                              #
# #           END Data DISKS                                     #
# # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
# #        STORAGE DISK ATTACHMENTS                              #
# #                                                              #

# resource "azurerm_virtual_machine_data_disk_attachment" "primary_app" {
#   count = var.primary_app_count
#   managed_disk_id = azurerm_managed_disk.primary_app[count.index].id
#   virtual_machine_id = azurerm_windows_virtual_machine.primary_app[count.index].id
#   lun = 0
#   caching = "ReadWrite"
# }
# #                                                              #
# #        END STORAGE DISK ATTACHMENTS                          #
# # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#           Custom Script Extension                            #
#                                                              #

# locals {
#   primary_app_alias_tag ="pa"
# }

# resource "azurerm_virtual_machine_extension" "primary_app_cs" {
#   count                = var.primary_app_count
#   name                 = "${azurerm_windows_virtual_machine.primary_app[count.index].name}-cs"
#   virtual_machine_id   = azurerm_windows_virtual_machine.primary_app[count.index].id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.9"

#   protected_settings = <<PROTECTEDSETTINGS
#   {
#     "commandToExecute": "powershell -command \"${local.attachdisk_script}\" && powershell -ExecutionPolicy Unrestricted -File attachdisk.ps1 && powershell -command \"${local.adoagent_script}\" && powershell -ExecutionPolicy Unrestricted -File az_agent_windows.ps1 ${local.primary_app_alias_tag} ${data.azurerm_key_vault_secret.environmentSecret.value}"
#   }
# PROTECTEDSETTINGS

#   tags = local.common_tags

#   depends_on = [
#     azurerm_virtual_machine_data_disk_attachment.primary_app
#   ]
# }

# resource "azurerm_virtual_machine_extension" "primary_app_cs" {
#   count                = var.primary_app_count
#   name                 = "${azurerm_windows_virtual_machine.primary_app[count.index].name}-cs"
#   virtual_machine_id   = azurerm_windows_virtual_machine.primary_app[count.index].id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.9"

#   protected_settings = <<PROTECTEDSETTINGS
#   {
#     "commandToExecute": "powershell -command \"${local.configuration_script}\" && powershell -ExecutionPolicy Unrestricted -File pmx-configurator.ps1"
#   }
# PROTECTEDSETTINGS

#   tags = local.common_tags

#   depends_on = [
#     azurerm_virtual_machine_extension.primary_app-jd
#   ]
# }

resource "azurerm_virtual_machine_extension" "primary_app_cs" {
  count                = var.azfileshare == true ? var.primary_app_count : 0
  name                 = "${azurerm_windows_virtual_machine.primary_app[count.index].name}-cs"
  virtual_machine_id   = azurerm_windows_virtual_machine.primary_app[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<PROTECTEDSETTINGS
  {
    "commandToExecute": "powershell -command \"${local.fs_mount_all_script};${local.fs_mount_script}\" && powershell -ExecutionPolicy Unrestricted -File fs_mount.ps1 ${data.azurerm_storage_account.pmx_fsst.primary_access_key}"
  }
PROTECTEDSETTINGS

  tags = local.common_tags
}

#                                                              #
#           END Custom Script Extension                        #
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#           JOIN DOMAIN                                        #
#                                                              #

resource "azurerm_virtual_machine_extension" "primary_app-jd" {
  count                = var.primary_app_count
  name                 = "DomainJoin"
  virtual_machine_id   = azurerm_windows_virtual_machine.primary_app[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = <<SETTINGS
    {
    "Name": "${var.domain.main.name}",
    "User": "${var.domain.main.user}@${var.domain.main.name}",
    "Restart": "true",
    "Options": "3"
    }
  SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#     {
#         "Password": "${var.domain.main.password}"
#     }
#   PROTECTED_SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
        "Password": "${data.azurerm_key_vault_secret.adds_credsecret.value}"
    }
  PROTECTED_SETTINGS

  tags = local.common_tags

  depends_on = [
    azurerm_virtual_machine_extension.primary_app_cs
  ]
}

#                                                              #
#           END DOMAIN JOIN                                    #
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#           Security Group Attachment                          #
#                                                              #

# resource "azurerm_network_interface_application_security_group_association" "primary_app" {
#   count = var.primary_app_count
#   network_interface_id          = azurerm_network_interface.primary_app[count.index].id
#   application_security_group_id = module.security_groups.application_security_groups[local.application_security_groups.app_primary]
# }

#                                                              #
#           END Security Group Attachment                      #
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

