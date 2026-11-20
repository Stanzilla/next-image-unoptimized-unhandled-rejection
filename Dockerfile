FROM node:26-slim
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# Optional: test another Next.js version, for example --build-arg NEXT_VERSION=latest
ARG NEXT_VERSION=
# Optional: --build-arg WORKAROUND=1 sets images.maximumDiskCacheSize: 0
ARG WORKAROUND=0
ENV WORKAROUND=$WORKAROUND

COPY package.json next.config.js exit-on-unhandled-rejection.cjs ./
COPY app ./app
RUN npm install --no-audit --no-fund \
 && if [ -n "$NEXT_VERSION" ]; then npm install --no-audit --no-fund "next@$NEXT_VERSION"; fi
RUN npx next build

# Typical production image: files are copied and built as root, the server runs as a non-root user.
USER node
EXPOSE 3000
CMD ["node_modules/.bin/next", "start"]
