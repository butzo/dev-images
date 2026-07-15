# Local image builds (CI does the weekly ones — see .github/workflows/build.yml)
registry := "ghcr.io/butzo"
bust := `date +%F`

default: build

# build base, then aio
build: build-base build-aio

# build the base image (dated cache bust refreshes pacman once a day)
build-base:
    podman build --build-arg CACHE_BUST={{bust}} \
      -f Containerfile.base -t {{registry}}/arch-dev:base .

# build aio on top of the local base image
build-aio:
    podman build --build-arg BASE={{registry}}/arch-dev:base \
      -f Containerfile.aio -t {{registry}}/arch-dev:aio .

# Force-fresh rebuild (ignores layer cache entirely)
rebuild:
    podman build --no-cache -f Containerfile.base -t {{registry}}/arch-dev:base .
    podman build --no-cache --build-arg BASE={{registry}}/arch-dev:base \
      -f Containerfile.aio -t {{registry}}/arch-dev:aio .

# push the local base and aio tags to the registry
push:
    podman push {{registry}}/arch-dev:base
    podman push {{registry}}/arch-dev:aio

# pull the latest aio image
pull:
    podman pull {{registry}}/arch-dev:aio

# remove dangling images
prune:
    podman image prune -f
