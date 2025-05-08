#!/bin/bash

docker run --rm -v ${TARGET_PATH}:/root/.cache/bionemo ${DOCKER_IMAGE_NAME}:${TAG} download_bionemo_data esm2/testdata_esm2_pretrain:2.0
