# syntax=docker/dockerfile:1

ARG NODE_VERSION=22.21.1

FROM node:${NODE_VERSION}-alpine

WORKDIR /usr/src/app

# Downloading dependencies
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

# Run the application as a non-root user.
USER node

# Copy the rest of the source files into the image.
COPY . .

# Expose the port that the application listens on.
EXPOSE 5000

# Run the application.
CMD ["node", "index.js"]
