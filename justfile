# Local image builds (CI does the weekly ones — see .github/workflows/build.yml)
registry := "ghcr.io/butzo"
bust := `date +%F`

default: build

build: build-base build-aio

build-base:
    podman build --build-arg CACHE_BUST={{bust}} \
      -f Containerfile.base -t {{registry}}/arch-dev:base .

build-aio:
    podman build --build-arg BASE={{registry}}/arch-dev:base \
      -f Containerfile.aio -t {{registry}}/arch-dev:aio .

# Force-fresh rebuild (ignores layer cache entirely)
rebuild:
    podman build --no-cache -f Containerfile.base -t {{registry}}/arch-dev:base .
    podman build --no-cache --build-arg BASE={{registry}}/arch-dev:base \
      -f Containerfile.aio -t {{registry}}/arch-dev:aio .

push:
    podman push {{registry}}/arch-dev:base
    podman push {{registry}}/arch-dev:aio

pull:
    podman pull {{registry}}/arch-dev:aio

prune:
    podman image prune -f
