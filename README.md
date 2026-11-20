# `/_next/image` with `images.unoptimized: true` causes an unhandled rejection (EACCES mkdir)

Minimal reproduction for a Next.js bug. App Router, one page, `images: { unoptimized: true }`.

## Steps

Requires Docker and curl.

```sh
./repro.sh                         # next@16.5.0-canary.58 (package.json)
NEXT_VERSION=16.4.6 ./repro.sh     # latest stable
WORKAROUND=1 ./repro.sh            # adds images.maximumDiskCacheSize: 0
```

`repro.sh` builds the app as root (`Dockerfile`), then runs the server as the `node` user. This is the usual `USER node` production image: the server cannot write to `.next`. It then requests `GET /_next/image?url=/foo.png&w=64&q=75` two times, and it does this for three server modes:

1. `next start`
2. `node .next/standalone/server.js`
3. `node -r ./exit-on-unhandled-rejection.cjs .next/standalone/server.js`. The preload makes the process exit on an unhandled rejection, as some hosts do (for example Platformatic Watt exits the worker with code 20).

`next start` prints a warning about `output: 'standalone'`. That warning is not related to this bug.

## Expected

With `unoptimized: true`, `/_next/image` returns 404 and Next.js does not touch the disk. No error is logged.

## Actual

Each request to `/_next/image` returns 404, but Next.js also starts `mkdir <distDir>/cache/images` and nothing handles the rejected promise:

```
⨯ unhandledRejection: Error: EACCES: permission denied, mkdir '/app/.next/cache/images'
    at async Object.mkdir (node:internal/fs/promises:1719:10)
    at async /app/node_modules/next/dist/server/lib/disk-lru-cache.external.js:36:17 {
  errno: -13, code: 'EACCES', syscall: 'mkdir', path: '/app/.next/cache/images'
}
```

| Next.js | Server mode | `/_next/image` | Unhandled rejections | Process |
|---|---|---|---|---|
| 16.5.0-canary.58, 16.4.6 | `next start` | 404 | 1 per request | keeps running |
| 16.5.0-canary.58, 16.4.6 | standalone `server.js` | 404 | 1 per request | keeps running |
| 16.5.0-canary.58, 16.4.6 | standalone, host exits on unhandled rejection | no response (connection closed) | 1 | exits, code 1 |
| any of the above, `WORKAROUND=1` | all three modes | 404 | 0 | keeps running |

Plain `next start` and standalone do not crash, because Next.js installs its own `unhandledRejection` listener that only logs. The process exits only when the host treats unhandled rejections as fatal.

## Workaround

```js
images: { unoptimized: true, maximumDiskCacheSize: 0 }
```
