#!/bin/bash

export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/

echo "Logging in to $REGISTRY ..."
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY

# Create ECR registry if it does not exist
REGISTRY_COUNT=$(aws ecr describe-repositories | grep ${DOCKER_IMAGE_NAME} | wc -l)
if [ "$REGISTRY_COUNT" == "0" ]; then
        echo ""
        echo "Creating ECR repository ${DOCKER_IMAGE_NAME} ..."
        aws ecr create-repository --repository-name ${DOCKER_IMAGE_NAME}
fi

# Push image
echo "pushing image: ${REGISTRY}${DOCKER_IMAGE_NAME}:aws"
docker image push ${REGISTRY}${DOCKER_IMAGE_NAME}:aws
