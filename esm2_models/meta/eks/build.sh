#!/bin/bash

# docker build -t ${DOCKER_IMAGE_NAME}:${TAG} .
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/
docker build -t ${REGISTRY}${DOCKER_IMAGE_NAME}:${TAG} .
