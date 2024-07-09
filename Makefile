
VERSION ?= latest

DOCKER_HUB ?= docker.io
DOCKER_IMAGE_NAME=devops/tools
DOCKER_IMAGE_ID = $(DOCKER_HUB)/$(DOCKER_IMAGE_NAME)
DOCKER_IMAGE_URI=${DOCKER_IMAGE_ID}:${VERSION}

DOCKER_PLATFORMS ?= linux/arm64,linux/amd64,linux/arm64/v8

image-build:
	docker build --no-cache -t ${DOCKER_IMAGE_URI} .

image-buildx:
	docker buildx build --platform="linux/arm64,linux/amd64" \
    	-t ${DOCKER_IMAGE_URI} .

image-ssh:
	docker run --privileged -it --rm --entrypoint='/bin/bash' ${DOCKER_IMAGE_URI}
