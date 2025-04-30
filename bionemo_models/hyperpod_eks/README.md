# Train Evolutionary Scale Models (ESM) with BioNemo

[NVIDIA BioNeMo](https://docs.nvidia.com/bionemo-framework/latest/) is a domain-specific machine learning framework for training and using foundation models for biology. This includes models for analyzing proteins, small molecules, and other biological molecules. To see the latest models available in BioNeMo 2.5 see [here](https://docs.nvidia.com/bionemo-framework/latest/models/).

This guidance provides step by step instructions to pretrain [ESM2](https://docs.nvidia.com/bionemo-framework/latest/models/ESM-2/) models with NVIDIA BioNeMo on Sagemaker HyPerPod slurm clusters.

## 0. Prerequisites

Have a EKS based Sagemaker HyperPod cluster with Nvidia GPUs. You can verify available number of GPUs and number of EFA devices like below:

```bash
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,INSTANCETYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa"

NAME                           INSTANCETYPE     GPU   EFA
hyperpod-i-048cd15160ee28917   ml.p5.48xlarge   8     32
hyperpod-i-09539ee1dd9971647   ml.p5.48xlarge   8     32
```

## 1. Setup environment variables

SSH into the head or login node of your cluster and run:

```
# Path to save training data and checkpoints

export AWS_REGION=us-west-1
export DOCKER_IMAGE_NAME=bionemo
export TAG=:aws
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/

export GPU_PER_NODE=8
export EFA_PER_NODE=32

export NUM_NODES=2
export OUTPUT_DIR=/fsx-shared
```

## 2. Pull this github repo

```bash
git clone https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework.git

cd guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework/source/hyperpod_eks
chmod 777 *.sh
```
## 3. Build and push Docker Image

We provide an AWS optimized Docker image that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly:

```bash
./build.sh
```
Once built you can push the Docker image to ECR as follows:

```bash
./push.sh
```

## 4. Download data

BioNeMo 2.5 container provides a CLI `download_bionemo_data` to download test or full UniProt dataset from NVIDIA Catalog which we can run as below. To that end we provide a `get-data-template.yaml`. First substitute the environment variables to generate `get-data.yaml` like below:

```bash
cat get-data-template.yaml | envsubst > get-data.yaml
```

And then run the job as below. The pod will take roughly 6 minutes to start as it is a roughly 35GB image.

```bash
kubectl apply -f get-data.yaml
```

To verify that the data is available in the filesystem, we need a dummy pod with the filesystem mounted. To do so, we provide       `view-fsx.yaml` which creates a pod called `fsx-share-test`. To view the contents of the file system we can exec in the pod as below:

```bash
# Create the pod
kubectl apply -f view-fsx.yaml
# Exec in the pod
kubectl exec fsx-share-test -- ls /fsx-shared
```
```bash
[ec2-user@ip-172-31-4-12 hyperpod_eks]$ kubectl exec fsx-share-test -- ls /fsx-shared
006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz
006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar
test.txt
```

Once done, export the `DATA_DIR` as an environment variable as below using the `*.untar` folder name:

```
export DATA_DIR=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar
```


## 5. Pretrain ESM2 models

Now we are ready to submit distributed training jobs to pretrain `ESM2` models. We provide the `esm2-pretrain-template.yaml` script to run training on 2 `p5.48xlarge` nodes with `8xH100 80 GB` GPUs. Make sure data paths and model configuration is correct if you are running on custom data. To kick off distributed training execute:

```bash
cat esm2-pretrain-template.yaml | envsubst > esm2-pretrain.yaml

kubectl apply -f esm2-pretrain.yaml

```
