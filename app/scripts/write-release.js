// Records which release this build is - its version and the colour its page is
// drawn in - in dist/release.json, from the APP_VERSION and APP_COLOUR
// environment variables. Run after `npm run build`.
//
// They're written into the build rather than read from app settings at run
// time, so they travel with the code when slots are swapped.
const { writeFileSync } = require("fs");

const release = {
  version: process.env.APP_VERSION || "dev",
  colour: process.env.APP_COLOUR || "grey",
};
writeFileSync("dist/release.json", JSON.stringify(release));
console.log(`wrote dist/release.json: ${JSON.stringify(release)}`);
