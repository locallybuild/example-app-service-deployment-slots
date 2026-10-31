# ---------------------------------------------------------------------------
# Container Registry - for storing the Container Images within Locally.
#
# App Service pulls the images from here, the same as you'd host a private
# image on Azure. The admin user is only used by Terraform to push the images;
# App Service pulls them with its managed identity.
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.name_prefix, "-", "")}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Data-plane role assignment - lets the web app (and its slot) pull images.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# Build the app in ../../app once per release and push both into the Locally
# ACR. The release's version and colour are passed as build arguments and
# baked into the image, so each tag is a different build of the code.
#
# The images are built for the host architecture: Locally runs the containers
# on this same machine, so no cross-arch build is needed. To run them on Azure
# App Service instead, build and push linux/amd64 (or multi-arch) images, e.g.
# with `docker buildx build --platform linux/amd64`.
# ---------------------------------------------------------------------------
resource "terraform_data" "build_and_push" {
  for_each = local.releases

  triggers_replace = [
    azurerm_container_registry.main.login_server,
    local.image_tags[each.key],
  ]

  provisioner "local-exec" {
    # The registry password is passed on stdin (--password-stdin) via an env var
    # rather than as a -p argument, so it never appears in the process list.
    environment = {
      REGISTRY_PASSWORD = azurerm_container_registry.main.admin_password
    }
    command = <<-EOT
      set -eu
      printf '%s' "$REGISTRY_PASSWORD" | docker login ${azurerm_container_registry.main.login_server} -u ${azurerm_container_registry.main.admin_username} --password-stdin
      docker build --build-arg APP_VERSION=${each.key} --build-arg APP_COLOUR=${each.value.colour} -t ${azurerm_container_registry.main.login_server}/${local.image_name}:${local.image_tags[each.key]} ${path.module}/../../app
      docker push ${azurerm_container_registry.main.login_server}/${local.image_name}:${local.image_tags[each.key]}
    EOT
  }
}
