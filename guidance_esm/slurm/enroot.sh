#!/bin/bash

file_name=${TARGET_PATH}/${DOCKER_IMAGE_NAME}.sqsh
[ -f $file_name ] && rm $file_name

enroot import -o $file_name dockerd://${DOCKER_IMAGE_NAME}:${TAG}