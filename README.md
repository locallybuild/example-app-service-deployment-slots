```
ooooo                                      oooo  oooo              
`888'                                      `888  `888              
 888          .ooooo.   .ooooo.   .oooo.    888   888  oooo    ooo 
 888         d88' `88b d88' `"Y8 `P  )88b   888   888   `88.  .8'
 888         888   888 888        .oP"888   888   888    `88..8'
 888       o 888   888 888   .o8 d8(  888   888   888     `888'
o888ooooood8 `Y8bod8P' `Y8bod8P' `Y888""8o o888o o888o     .8'
                                                       .o..P'
                                                       `Y8P'
```

# Example: Blue/green deployments with App Service deployment slots within Locally

This example shows how to do a blue/green deployment with [App Service deployment slots](https://learn.microsoft.com/azure/app-service/deploy-staging-slots) on [Locally Build](https://locally.build). A Linux web app runs release **v1 (blue)** in production, and a `staging` slot runs release **v2 (green)**. Swapping the slots puts v2 live and moves v1 into staging, without either container being redeployed.

```
                    before the swap                          after the swap
 production  ─▶  v1 (blue)   SLOT_ENVIRONMENT=production   v2 (green)  SLOT_ENVIRONMENT=production
 <app>             RELEASE_NOTES="v1: ..."                   RELEASE_NOTES="v2: ..."

 staging     ─▶  v2 (green)  SLOT_ENVIRONMENT=staging      v1 (blue)   SLOT_ENVIRONMENT=staging
 <app>-staging     RELEASE_NOTES="v2: ..."                   RELEASE_NOTES="v1: ..."
```

The app is a single page, written in TypeScript (Node.js and Express). The source lives in [`app/`](./app), alongside the infrastructure that runs it. The page shows:

* the release - its version and colour, drawn as a big coloured banner.
* the value of two app settings: `SLOT_ENVIRONMENT`, a slot setting ("sticky"), and `RELEASE_NOTES`, an ordinary app setting.
* where it's running - the hostname you reached it on, and the `WEBSITE_*` variables App Service sets.

The same information is available as JSON at `/api/info`, which is handy for checking a swap from the command line.

### What a swap moves, and what it doesn't

A swap exchanges what's running in two slots. The parts that belong to the **release** move:

* the container image (the code).
* ordinary app settings, like `RELEASE_NOTES`.

The parts that belong to the **slot** stay where they are:

* its hostname - production is always `<app>`, staging is always `<app>-staging`.
* slot settings. A setting becomes a slot setting when its name is listed in the web app's `sticky_settings` block. Here that's `SLOT_ENVIRONMENT`. This is where you'd put anything that must differ between production and staging, like which database to use.

### Why two image builds

The version and colour are baked into the image at build time (the `Dockerfile` runs `npm run release`, which writes them to `dist/release.json`) rather than passed in as app settings. Terraform builds the app twice, once per release, with `--build-arg APP_VERSION=... --build-arg APP_COLOUR=...`, and pushes two tags to the Container Registry. Production runs one tag and staging runs the other.

That way the banner can only change if the image changes, so it shows honestly that the code moved. If the version were an app setting instead, a swap would still move it (it isn't sticky), but you couldn't tell from the page whether the code had moved or only the setting had.

### Pulling the image without credentials

Both slots pull their image with a **user-assigned managed identity** that holds the `AcrPull` role on the Container Registry (`container_registry_use_managed_identity = true`), so no registry password is stored in the web app. The registry's admin user is only used by Terraform to push the images.

## Requirements

* [Locally Build](https://locally.build).
* Either [HashiCorp Terraform](https://terraform.io) or [OpenTofu](https://opentofu.org).
* Either [Docker](https://www.docker.com) or [Podman](https://podman.io) (recommended).
* The Locally Plugin for `Microsoft.ContainerRegistry` installed (`locally plugin install --name Microsoft.ContainerRegistry`).
* The Locally Plugin for `Microsoft.Insights` installed (`locally plugin install --name Microsoft.Insights`).
* The Locally Plugin for `Microsoft.OperationalInsights` installed (`locally plugin install --name Microsoft.OperationalInsights`).
* The Locally Plugin for `Microsoft.Web` installed (`locally plugin install --name Microsoft.Web`).

## Running the example

First up, we need to ensure our container runtime (Docker or Podman) is running, then launch Locally:

```bash
locally build
```

With Locally running, in another terminal we can initialise Terraform, which both downloads the providers we need and configures the module for use:

```bash
cd environments/locally
terraform init
```

> [!NOTE]
> You can use OpenTofu instead by running `tofu` wherever this says `terraform`.

With Terraform initialised, we can then provision the example by running:

```bash
locally run terraform apply
```

As part of the apply, the app is built twice with `docker build` (once per release) and both images are pushed into the Container Registry, so the `docker` command needs to be available (with Podman, the `podman-docker` shim or a `docker` alias works).

Once you approve the plan and the resources have been deployed, both slots are running at the URLs in the outputs:

```
production_url = "https://locally-example-slots-app.furnace.locally:5663"
resource_group = "locally-example-slots-resources"
staging_url    = "https://locally-example-slots-app-staging.furnace.locally:5663"
web_app        = "locally-example-slots-app"
```

[Open production](https://locally-example-slots-app.furnace.locally:5663) and you'll see v1 in blue. [Open staging](https://locally-example-slots-app-staging.furnace.locally:5663) and you'll see v2 in green. Or from the command line:

```bash
curl -s https://locally-example-slots-app.furnace.locally:5663/api/info
curl -s https://locally-example-slots-app-staging.furnace.locally:5663/api/info
```

---

As this Terraform configuration sends both slots' logs into a Log Analytics Workspace, we can then query them within [the Locally Dashboard, in the Monitoring section](https://localhost:5678/monitoring/components), by running:

```
AppServiceConsoleLogs | order by TimeGenerated desc
```

## Swapping the slots

> [!WARNING]
> Swapping currently fails on Locally for slots that run a container image, like these - see [Known issue on Locally](#known-issue-on-locally). The steps below are what works on Azure.

Once you're happy with v2 in staging, swap it into production:

```bash
locally run az webapp deployment slot swap \
  --resource-group locally-example-slots-resources \
  --name locally-example-slots-app \
  --slot staging \
  --target-slot production
```

App Service restarts both slots with their new contents, so give it a minute. Then reload both pages. Production now shows v2 (green) with `RELEASE_NOTES` set to `v2: the green release`, and staging shows v1 (blue) - the code and the ordinary setting have changed places. `SLOT_ENVIRONMENT` hasn't moved: production still says `production` and staging still says `staging`.

If v2 turns out to be broken, rolling back is the same command again. Swapping a second time puts v1 back in production and v2 back in staging:

```bash
locally run az webapp deployment slot swap \
  --resource-group locally-example-slots-resources \
  --name locally-example-slots-app \
  --slot staging \
  --target-slot production
```

### Swapping with Terraform, and drift

The swap above happens outside Terraform. Terraform's configuration still says production runs v1 and staging runs v2, so after a swap `locally run terraform plan` reports drift: it wants to put the v1 image and v1's `RELEASE_NOTES` back on production, and v2's on staging. Applying that plan would undo the swap - and do it by redeploying both slots, rather than with a swap.

There are three ways to keep the two in step:

* **Swap back.** Swap a second time (the rollback command above) before running `terraform apply` again, and `plan` shows no changes.
* **Swap, then update the configuration.** After swapping, change `production_release` and `staging_release` in [`locals.tf`](./modules/app-service-deployment-slots/locals.tf) to match what's now running, so `plan` is clean again. The next release goes into staging by changing `staging_release`.
* **Let Terraform do the swap.** The [`azurerm_web_app_active_slot`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/web_app_active_slot) resource swaps a slot into production as part of an apply:

  ```hcl
  resource "azurerm_web_app_active_slot" "main" {
    slot_id = azurerm_linux_web_app_slot.staging.id
  }
  ```

  It runs the swap when it's created (or when `slot_id` changes), but the web app and slot resources still describe what each slot ran before the swap, so they'll show the same drift on the next plan. It suits a pipeline that swaps once per release and then updates the configuration, rather than a swap you repeat by hand.

## Notes

Deployment slots need a Standard (S1) or higher App Service plan, so this example uses S1 rather than the B1 used by the other App Service examples. Slots share the plan's instances with the production app.

A slot doesn't inherit anything from the production app - not its identity, its image or its app settings - so the slot resource repeats them. Only `sticky_settings` is set on the web app alone, and applies to all its slots.

On Azure, a swap first applies the target slot's slot settings to the source slot and restarts it, then waits for it to warm up before switching traffic, so production doesn't serve a cold container. The `health_check_path` (`/healthz`) gives App Service an endpoint to check.

This example has no sign-in of its own: anyone who can reach either slot can see its page. A real app would sit behind authentication, and you'd usually restrict who can reach the staging slot too.

### Known issue on Locally

Swapping slots that run a container image currently fails on Locally. `az webapp deployment slot swap` (or `POST .../slots/staging/slotsswap`) returns `500 Internal Server Error` with:

```
the runtime swap failed, so no ARM state was changed: Furnace refused to swap
"locally-example-slots-app-staging" and "locally-example-slots-app" (500):
adopting "locally-example-slots-app"'s deployment into "locally-example-slots-app-staging":
copying deployment content from .../furnace/deployments/locally-example-slots-app.furnace.locally/<id>/app:
open ...: no such file or directory
```

Nothing changes, so both slots keep serving what they were. Slots that run code deployed as a zip package (a built-in runtime such as Node.js, with `zip_deploy_file` or `az webapp deploy`) swap correctly on Locally, sticky settings included. The deployment itself, both slots, and the sticky and non-sticky settings all work as described above.

## Tearing it down

```bash
cd environments/locally
locally run terraform destroy
```
