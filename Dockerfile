FROM node:24-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:24-alpine AS runtime
WORKDIR /app

# Deliberately no PORT: nitro's node server defaults to 3000 (what
# docker-compose.yml expects) while Cloud Run injects its own PORT in
# production, which must not be shadowed by a baked-in value.
ENV HOST=0.0.0.0
ENV NODE_ENV=production

COPY --from=build /app/.output ./.output

CMD ["node", "./.output/server/index.mjs"]
