## 0. Available ESM2 models on HuggingFace

1. [facebook/esm2_t6_8M_UR50D](https://huggingface.co/facebook/esm2_t6_8M_UR50D)
2. [facebook/esm2_t12_35M_UR50D](https://huggingface.co/facebook/esm2_t12_35M_UR50D)
3. [facebook/esm2_t30_150M_UR50D](https://huggingface.co/facebook/esm2_t30_150M_UR50D)
4. [facebook/esm2_t33_650M_UR50D](https://huggingface.co/facebook/esm2_t33_650M_UR50D)
5. [facebook/esm2_t36_3B_UR50D](https://huggingface.co/facebook/esm2_t36_3B_UR50D)
6. [facebook/esm2_t48_15B_UR50D](https://huggingface.co/facebook/esm2_t48_15B_UR50D)


## 1. Setup environment variables

SSH into the head or login node of your cluster and run:

```
# Path to save training data and checkpoints
#export TARGET_PATH=/fsx/ubuntu/esm
export TARGET_PATH=/fsx-shared/esm
export DOCKER_IMAGE_NAME=esm
export TAG=aws
export MODEL=facebook/esm2_t36_3B_UR50D
#use sepcific AWS region
export AWS_REGION=us-east-1
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
cat download-data-template.yaml | envsubst > download-data-real.yaml
kubectl apply -f download-data-real.yaml
pod/download-uniref-data created
```
It would download the data and partitions the data in 50 .csv files in the folder specified by the `TARGET_PATH` environment variable. 
The whole process should take less than 30 mins. 
You can check the progress of data download by tailing the pod's log:

```bash
kubectl logs -f download-uniref-data
04/18/2025 22:03:54 - INFO - Parsing arguments
04/18/2025 22:03:54 - INFO - Downloading FASTA
04/18/2025 22:03:54 - INFO - Downloading https://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref50/uniref50.fasta.gz to /workspace/tmpoynct05t/fasta
https://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref50/uniref50.fasta.gz: 100%|██████████| 13.5G/13.5G [00:53<00:00, 270MB/s]
04/18/2025 22:04:48 - INFO - Generating csv files
Reading FASTA file
496248it [00:10, 67980.24it/s]04/18/2025 22:04:59 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x000.csv
993450it [00:32, 90583.72it/s]04/18/2025 22:05:21 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x001.csv
1492283it [00:47, 102759.08it/s]04/18/2025 22:05:35 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x002.csv
1995100it [00:59, 113624.67it/s]04/18/2025 22:05:48 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x003.csv
...
```

## 5. Convert CSVs to HuggingFace Dataset and Tokenize

Next we need to tokenize the dataset in order to provide training data in the specified format. This will split the data in training, test and validation folders, tokenize them and save the arrow files in `processed` folder.

```bash
kubectl apply -f preprocess.yaml
```

## 6. using DDP

Now we are ready to submit distributed training jobs to pretrain ESM2 models. We provide the `train-esm.slurm` script to run training on 2 p5.48xlarge nodes with 8xH100 80 GB GPUs. Make sure data paths and model configuration is correct if you are running on custom data. 

To kick off distributed training execute:

```bash
cat train-ddp-template.yaml | envsubst > train-ddp.yaml
kubectl apply -f train-ddp.yaml
```

## 7. Using FSDP
```bash
cat train-fsdp-template.yaml.yaml | envsubst > train-fsdp.yaml
kubectl apply -f train-fsdp.yaml
```

sbatch train_fsdp.sh
