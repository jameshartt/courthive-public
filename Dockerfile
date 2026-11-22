# Club-neutral content image of the CourtHive public pages for the jim-dot-tennis bundle.
# See BUNDLE.md. Build with bundle/build.sh (it supplies the build arguments).
#
# The final stage holds only the built files (/dist), the licences (/licenses)
# and a shell. Its default command empties /out (or $TARGET_DIR) and copies
# /dist into it, so a one-shot compose service can fill a named volume that a
# stock Caddy mounts read-only and serves at /public/.

# Node major from upstream's .node-version / engines (node >=26). Node 26 ships
# no corepack, so the pnpm pinned in package.json#packageManager is installed with npm.
FROM node:26-alpine AS build
ENV CI=true \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
WORKDIR /src

# Refuse link: overrides before anything is installed.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY bundle/check-links.mjs bundle/
RUN node bundle/check-links.mjs \
 && npm install -g --no-fund --no-audit "$(node -p "require('./package.json').packageManager")" \
 && pnpm --version

RUN pnpm install --frozen-lockfile
COPY . .

ARG VERSION
ARG UPSTREAM_VERSION
ARG UPSTREAM_COMMIT
ARG UPSTREAM_REPO
ARG FORK_REPO
ARG FORK_COMMIT
RUN set -eu; \
    for v in VERSION UPSTREAM_VERSION UPSTREAM_COMMIT UPSTREAM_REPO FORK_REPO FORK_COMMIT; do \
      eval "val=\${$v:-}"; [ -n "$val" ] || { echo "build argument $v is required (use bundle/build.sh)"; exit 1; }; \
    done; \
    pkgver=$(node -p "require('./package.json').version"); \
    [ "$pkgver" = "$UPSTREAM_VERSION" ] || { echo "UPSTREAM_VERSION $UPSTREAM_VERSION != package.json $pkgver"; exit 1; }; \
    case "$VERSION" in "$UPSTREAM_VERSION"-jdt.*) ;; *) echo "VERSION $VERSION must be $UPSTREAM_VERSION-jdt.<n>"; exit 1;; esac; \
    BUILD_COMMIT=$(echo "$FORK_COMMIT" | cut -c1-7) pnpm build; \
    mkdir -p /licenses; \
    cp LICENSE /licenses/LICENSE-courthive-public; \
    node bundle/third-party-licenses.mjs --maps dist /licenses/THIRD-PARTY-LICENSES.txt; \
    printf '%s\n' \
      "CourtHive public tournament pages, image version $VERSION." \
      "" \
      "Built from a fork of the CourtHive repository $UPSTREAM_REPO" \
      "at upstream commit $UPSTREAM_COMMIT (upstream version $UPSTREAM_VERSION)," \
      "with the changes listed in BUNDLE.md of the fork $FORK_REPO" \
      "at commit $FORK_COMMIT." \
      "" \
      "This is not an official CourtHive build. The public pages are MIT licensed," \
      "Copyright (c) 2024 Charles Allen; see LICENSE-courthive-public." \
      "Third-party packages bundled in the built files: THIRD-PARTY-LICENSES.txt." \
      > /licenses/NOTICE; \
    find dist -name '*.map' -delete; \
    if find dist -name '*.map' | grep -q .; then echo "source maps remain"; exit 1; fi

FROM busybox:1.37
ARG VERSION
ARG UPSTREAM_VERSION
ARG UPSTREAM_COMMIT
ARG UPSTREAM_REPO
ARG FORK_REPO
ARG FORK_COMMIT
LABEL org.opencontainers.image.title="courthive-public" \
      org.opencontainers.image.description="Club-neutral CourtHive public pages built files (content image) for the jim-dot-tennis bundle; not an official CourtHive build" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$FORK_COMMIT" \
      org.opencontainers.image.source="$FORK_REPO" \
      org.opencontainers.image.licenses="MIT" \
      jdt.upstream.source="$UPSTREAM_REPO" \
      jdt.upstream.commit="$UPSTREAM_COMMIT" \
      jdt.upstream.version="$UPSTREAM_VERSION"
COPY --from=build /src/dist /dist
COPY --from=build /licenses /licenses
COPY bundle/copy-dist.sh /usr/local/bin/copy-dist
ENV TARGET_DIR=/out
CMD ["/usr/local/bin/copy-dist"]
