locals {
  # The application image, built from ../../app and pushed into the Locally
  # Container Registry by 3-container-registry.tf.
  image_name = "app-service-deployment-slots"

  # The two releases this example deploys. Each is its own image build, with the
  # version and colour baked in, so swapping slots visibly moves the code:
  #
  #   * production runs v1 (blue)
  #   * staging runs v2 (green) - the release about to go live
  releases = {
    v1 = { colour = "blue", notes = "v1: the blue release" }
    v2 = { colour = "green", notes = "v2: the green release" }
  }
  production_release = "v1"
  staging_release    = "v2"

  # Each image is tagged with a hash of the application directory plus its
  # release, so any change to the app produces new tags: that re-triggers the
  # builds and pushes, and rolls both slots onto the freshly built images. Build
  # artifacts are excluded so they don't churn the hash.
  app_dir = "${path.module}/../../app"
  app_files = [
    for f in fileset(local.app_dir, "**") : f
    if !startswith(f, "node_modules/") && !startswith(f, "dist/")
  ]
  app_hash = substr(sha1(join(",", [for f in local.app_files : "${f}:${filesha1("${local.app_dir}/${f}")}"])), 0, 12)
  image_tags = {
    for version, _ in local.releases : version => "${local.app_hash}-${version}"
  }

  # The port the container listens on inside App Service (the app's PORT, exposed
  # to App Service as WEBSITES_PORT). App Service terminates TLS at the platform
  # and routes public traffic to the container on this port.
  app_port = 8080
}
