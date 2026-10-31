# ---------------------------------------------------------------------------
# User-Assigned Managed Identity - used by App Service to pull the image from
# the Container Registry, so neither slot needs registry credentials.
#
# Both slots use the same identity. A user-assigned identity exists before the
# web app does, so its AcrPull role is granted up front - the very first image
# pull succeeds rather than racing a grant that lands later.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "app" {
  name                = "${var.name_prefix}-app-id"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}
