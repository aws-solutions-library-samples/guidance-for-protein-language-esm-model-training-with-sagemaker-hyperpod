## 0. Available ESM2 models on HuggingFace

1. facebook/esm2_t6_8M_UR50D
2. facebook/esm2_t12_35M_UR50D
3. facebook/esm2_t30_150M_UR50D
4. facebook/esm2_t33_650M_UR50D
5. facebook/esm2_t36_3B_UR50D
6. facebook/esm2_t48_15B_UR50D





## 1. Setup environment variables

SSH into the head or login node of your cluster and run:

```
# Path to save training data and checkpoints
export TARGET_PATH=/fsx/ubuntu/esm
export DOCKER_IMAGE_NAME=esm
export TAG=aws
export MODEL=facebook/esm2_t36_3B_UR50D


export AWS_REGION=us-west-1
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/

export GPU_PER_NODE=8
export EFA_PER_NODE=32

export NUM_NODES=2
export OUTPUT_DIR=/fsx-shared
```

## 2. Build and push Docker Image

We provide an AWS optimized Docker image that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly:

```bash
./build.sh
```

Once built you can push the Docker image to ECR as follows:
```bash
./push.sh
```

## 4. Prepare dataset of training data

Next we need to download the Uniref50 training data. You can do so by running:

```bash
cat download_data.yaml | envsubst > download_data_real.yaml
kubectl apply -f download_data_real.yaml
pod/download-uniref-data created
```
It would download the data and partitions the data in 50 .csv files in `/fsx/ubuntu/csv` folder. The whole process should take less than 30 mins.

## 5. Convert CSVs to HuggingFace Dataset and Tokenize

Next we need to tokenize the dataset. This will split the data in training, test and validation folders, tokenize them and save the arrow files in `processed` folder.

```bash
kubectl apply -f preprocess.yaml
```

## 6. DDP

Now we are ready to submit distributed training jobs to pretrain ESM2 models. We provide the `train-esm.slurm` script to run training on 2 p5.48xlarge nodes with 8xH100 80 GB GPUs. Make sure data paths and model configuration is correct if you are running on custom data. 

To kick off distributed training execute:

```bash
cat train-ddp-template.yaml.yaml | envsubst > train-ddp.yaml
kubectl apply -f train-ddp.yaml
```

## 7. FSDP
```bash
cat train-fsdp-template.yaml.yaml | envsubst > train-fsdp.yaml
kubectl apply -f train-fsdp.yaml
```

sbatch train_fsdp.sh
