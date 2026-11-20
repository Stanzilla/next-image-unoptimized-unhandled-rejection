#!/bin/sh
# Builds the app as root, runs it as the `node` user and requests /_next/image.
# Usage: ./repro.sh                      (Next.js version from package.json)
#        NEXT_VERSION=latest ./repro.sh  (other Next.js version)
#        WORKAROUND=1 ./repro.sh         (images.maximumDiskCacheSize: 0)
set -eu
cd "$(dirname "$0")"

TAG="next-image-repro:${NEXT_VERSION:-pinned}-w${WORKAROUND:-0}"
docker build -q -t "$TAG" \
  --build-arg NEXT_VERSION="${NEXT_VERSION:-}" \
  --build-arg WORKAROUND="${WORKAROUND:-0}" . >/dev/null

echo "== image $TAG"
docker run --rm "$TAG" sh -c 'echo "next $(node -p "require(\"next/package.json\").version"), node $(node -v), user $(id -un)"; ls -ld .next .next/standalone/.next'

run_mode() {
  mode=$1
  shift
  echo
  echo "== mode: $mode ($*)"
  cid=$(docker run -d -p 127.0.0.1::3000 "$TAG" "$@")
  port=$(docker port "$cid" 3000/tcp | head -n 1 | sed 's/.*://')
  i=0
  until curl -s -o /dev/null "http://127.0.0.1:$port/" || [ $i -ge 60 ]; do i=$((i + 1)); sleep 1; done

  echo "GET /                -> $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/")"
  for n in 1 2; do
    echo "GET /_next/image #$n  -> $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/_next/image?url=%2Ffoo.png&w=64&q=75" || true)"
    sleep 2
    echo "   unhandledRejection lines in log so far: $(docker logs "$cid" 2>&1 | grep -c unhandledRejection || true)"
  done
  echo "GET / after          -> $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/" || true)"

  if [ "$(docker inspect -f '{{.State.Running}}' "$cid")" = true ]; then
    echo "process: still running"
    docker stop -t 2 "$cid" >/dev/null
  else
    echo "process: EXITED, exit code $(docker inspect -f '{{.State.ExitCode}}' "$cid")"
  fi
  echo "-- server log"
  docker logs "$cid" 2>&1 | sed 's/^/   /'
  docker rm "$cid" >/dev/null
}

run_mode "next start" node_modules/.bin/next start
run_mode "standalone" node .next/standalone/server.js
run_mode "standalone, host exits on unhandledRejection" node -r ./exit-on-unhandled-rejection.cjs .next/standalone/server.js
