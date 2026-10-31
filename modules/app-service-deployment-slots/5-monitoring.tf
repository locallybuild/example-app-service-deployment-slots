# ---------------------------------------------------------------------------
# Log Analytics - for storing the application's logs
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.name_prefix}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Diagnostic settings - ship both slots' Console Logs into the Log Analytics
# Workspace so they're KQL-queryable in the Monitoring -> Telemetry UI. A slot
# is its own resource, so it needs its own diagnostic setting. Within the
# Locally Dashboard these can be queried using:
#   AppServiceConsoleLogs | order by TimeGenerated desc
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "main" {
  for_each = {
    production = azurerm_linux_web_app.main.id
    staging    = azurerm_linux_web_app_slot.staging.id
  }

  name                       = "console-logs"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AppServiceConsoleLogs"
  }
}
