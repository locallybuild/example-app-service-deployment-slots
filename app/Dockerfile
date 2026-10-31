# Build stage: install everything (including TypeScript) and compile to dist/.
FROM node:22 AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# The release this image is: its version and the colour its page is drawn in.
# They're written into the build (dist/release.json) rather than read from app
# settings, so they travel with the code when slots are swapped.
ARG APP_VERSION=dev
ARG APP_COLOUR=grey
COPY scripts ./scripts
RUN APP_VERSION="$APP_VERSION" APP_COLOUR="$APP_COLOUR" npm run release

# Runtime stage: production dependencies and the compiled JavaScript only.
FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /src/dist ./dist
EXPOSE 8080
USER node
CMD ["node", "dist/index.js"]
