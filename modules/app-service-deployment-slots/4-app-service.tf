# ---------------------------------------------------------------------------
# App Service Plan - houses the web app and its staging slot. Slots run on the
# same plan (and the same instances) as the production app.
#
# Deployment slots need the Standard tier or higher - the Basic tier used by
# the other examples doesn't have them.
# ---------------------------------------------------------------------------
resource "azurerm_service_plan" "main" {
  name                = "${var.name_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# The web app itself is the "production" slot. It runs v1 (blue).
#
# Two app settings show what a swap does to configuration:
#
#   * SLOT_ENVIRONMENT is listed in sticky_settings, which makes it a slot
#     setting: it belongs to the slot, not the release, so it stays put when
#     the slots are swapped. Use this for anything that must differ between
#     production and staging - a database, a Key Vault reference, a feature
#     flag that's only on in staging.
#   * RELEASE_NOTES is an ordinary app setting: it travels with the code, so
#     after a swap production has staging's value.
#
# sticky_settings is set here on the web app, but applies to every slot.
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "main" {
  name                = "${var.name_prefix}-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  site_config {
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 2

    # Pull the image with the managed identity rather than registry credentials.
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app.client_id

    application_stack {
      docker_image_name   = "${local.image_name}:${local.image_tags[local.production_release]}"
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }
  }

  app_settings = {
    # App Service routes public traffic to the container on this port, and the
    # app binds to it (12-factor port binding).
    WEBSITES_PORT = tostring(local.app_port)
    PORT          = tostring(local.app_port)

    SLOT_ENVIRONMENT = "production"
    RELEASE_NOTES    = local.releases[local.production_release].notes
  }

  sticky_settings {
    app_setting_names = ["SLOT_ENVIRONMENT"]
  }

  # The images must exist in the registry, and the identity must be able to
  # pull them, before the app starts.
  depends_on = [
    terraform_data.build_and_push,
    azurerm_role_assignment.app_acr_pull,
  ]
}

# ---------------------------------------------------------------------------
# Staging slot - runs v2 (green), the release waiting to go live.
#
# A slot is a full web app of its own with its own hostname
# (<app>-staging.<domain>), so v2 can be tested there before it's swapped into
# production. Swapping exchanges the two slots' contents - image and ordinary
# app settings - while each slot keeps its slot settings and its hostname.
#
# A slot doesn't inherit anything from the production app, so the identity,
# registry settings and ports are repeated here.
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id
  https_only     = true
  tags           = var.tags

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  site_config {
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 2

    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_user_assigned_identity.app.client_id

    application_stack {
      docker_image_name   = "${local.image_name}:${local.image_tags[local.staging_release]}"
      docker_registry_url = "https://${azurerm_container_registry.main.login_server}"
    }
  }

  app_settings = {
    WEBSITES_PORT = tostring(local.app_port)
    PORT          = tostring(local.app_port)

    SLOT_ENVIRONMENT = "staging"
    RELEASE_NOTES    = local.releases[local.staging_release].notes
  }

  depends_on = [
    terraform_data.build_and_push,
    azurerm_role_assignment.app_acr_pull,
  ]
}
