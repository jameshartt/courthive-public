# Bundle branch (jim-dot-tennis)

Branch `jdt-bundle` builds the club-neutral image of the CourtHive public
pages for the jim-dot-tennis CourtHive bundle. It is upstream `master` at the
commit named in `bundle/UPSTREAM` (release 1.23.7) plus the commits below,
and nothing else. It is not a rebase of the old `jim-tennis-deploy` branch.

(The branch is not called `bundle` because the local ref
`bundle/club-neutral` already exists, and git cannot hold both.)

## How the bundle serves the pages

One origin per club, any hostname. A reverse proxy (Caddy) serves:

- `/public/`: these files (hash router, so no SPA fallback is needed);
- `/api/courthive/*`: the factory server (CFS), prefix stripped; the identity
  service (courthive-hiveid) gets `/api/courthive/auth/*` and
  `/api/courthive/account/*`, except the routes that stay on CFS;
- `/socket.io/*`: CFS socket.io, on the origin.

Every other path belongs to the jim-dot-tennis app.

## Changes on top of upstream

1. `pnpm-workspace.yaml`, `pnpm-lock.yaml`: upstream's `link:../<sibling>`
   overrides for `@courthive/provider-config`, `courthive-components` and
   `tods-competition-factory` removed; lockfile regenerated against npm with
   the pinned pnpm (`pnpm install --lockfile-only`). Upstream's own `ci.yml`
   strips the same lines and deletes the lockfile before installing.
2. Club-neutral build (no request ever leaves the serving host):
   - `index.html`: sets `window.dev` before boot (`baseURL`, `authURL` =
     `<origin>/api/courthive`; `amsURL`, `declarationsURL`, `queryBaseURL`
     under it). Every service reads `window.dev` before its localhost or
     `https://courthive.net` fallback.
   - `src/services/liveUpdates.ts`, `src/services/hiveidSocket.ts`: connect to
     the origin of the CFS base (socket.io takes the URL path as the
     namespace) with long-polling only (the WebSocket upgrade failed behind
     Caddy on HTTP/2).
   - `.env.production` (upstream has none): `VITE_SERVER=/api/courthive`,
     `VITE_SCORE_RELAY_URL=/api/courthive/relay` (the score relay has no
     `window.dev` override), `ENVIRONMENT=production`, `BASE_URL=public`.
   - `src/pages/tournament/tabs/infoTab/renderVenues.ts`: venue cards without
     the openstreetmap.org map iframe (`showMap: false`).
3. Bundle files: `Dockerfile`, `.dockerignore`, `bundle/*`, this file, the
   draft workflow `.github/workflows/bundle-image.yml`, and one line in
   `vite.config.ts` that takes the commit for `version.json` from
   `BUILD_COMMIT` (the image build has no `.git`).

## Services the bundle does not ship

The public pages call these under `/api/courthive/...`; without them the
request fails on the serving host and the page says so or shows nothing:

| Feature | Path called | Without the service |
| --- | --- | --- |
| Score relay (live point-by-point scores, crowd "sign in to share") | socket.io `/socket.io/`, namespace `/api/courthive/relay/live` and `/crowd` | Silent: no live overlay; the handshake reaches CFS, which refuses the namespace. Practice scoring stays local. |
| AMS registration | `GET /api/courthive/ams/sanctioning/registration/:id` | "Registration is not open for this tournament." |
| Declarations (availability, consent, partner invites, my registrations) | `/api/courthive/declarations/...` | Visible: "This invitation was not found.", consent check fails. |
| Query service (programs, tournament search with a provider) | `/api/courthive/query/...` | "Could not load the program directory." |
| Rankings | `/api/rankings/...` (root path, no override) | Request goes to the jim-dot-tennis app; "No rank lists are currently published." |
| HiveID player sign-in | `/api/courthive/auth/hiveid/...`, socket.io namespace `/hiveid` on CFS | Works only if the bundle routes `auth/*` to courthive-hiveid; otherwise "This sign-in link is invalid or has expired." |

## Image

Final stage: busybox with `/dist` (built files, no `*.map`), `/licenses`
(`LICENSE-courthive-public` = upstream's MIT `LICENSE`, `NOTICE`,
`THIRD-PARTY-LICENSES.txt` from the build's source maps) and `copy-dist` as
the default command: it empties `$TARGET_DIR` (default `/out`) and copies
`/dist` into it, for a one-shot compose service filling a volume Caddy mounts.

    bundle/build.sh 1     # needs a clean tree; tags <upstream version>-jdt.1

Nothing is pushed by `bundle/build.sh`. The workflow is a draft and has never
run.

## Moving to a new upstream

1. Start a new branch from the new upstream commit; cherry-pick the commits
   above. Do not merge upstream into this branch.
2. Remove any `link:` entries upstream added (`node bundle/check-links.mjs`
   names them) and regenerate the lockfile with the pinned pnpm.
3. Grep `src/` for `courthive.net`, `window.dev`, `import.meta.env.VITE_`,
   `localhost` and `io(`: every service must end up same-origin.
4. Update `bundle/UPSTREAM`, rebuild, extract `/dist` and re-run the host scan
   and the headless-browser probe before releasing an image.

Keep the changes small and listed here.
