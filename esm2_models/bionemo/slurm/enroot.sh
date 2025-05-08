#!/bin/bash

rm ${TARGET_PATH}/${DOCKER_IMAGE_NAME}.sqsh
echo "Preparing  image  ${TARGET_PATH}/${DOCKER_IMAGE_NAME}.sqsh .."
enroot import -o ${TARGET_PATH}/${DOCKER_IMAGE_NAME}.sqsh dockerd://${DOCKER_IMAGE_NAME}:${TAG}
