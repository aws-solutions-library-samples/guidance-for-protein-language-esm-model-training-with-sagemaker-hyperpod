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
```

## 2. Build Docker Image

We provide an AWS optimized Docker image that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly:

```bash
./build.sh
```

## 3. Build Enroot Image

[NVIDIA Enroot](https://github.com/NVIDIA/enroot) is a lightweight container runtime that allows users to run containerized applications without requiring full-fledged container engines like Docker. It is designed for HPC environments, particularly the Slurm Workload Manager. To convert Docker images to Enroot squash files:

```bash
./enroot.sh
```

## 4. Prepare dataset

Next we need to download the Uniref50 training data. You can do so by running:

```bash
docker run --rm -v ${TARGET_PATH}:/workspace ${DOCKER_IMAGE_NAME}:${TAG} -v /workspace:${TARGET_PATH} python3 0.download_data.py --output_dir ${TARGET_PATH}
```
It would download the data and partitions the data in 50 .csv files in `/fsx/ubuntu/csv` folder. The whole process should take less than 30 mins.

## 5. Convert CSVs to HuggingFace Dataset and Tokenize

Next we need to tokenize the dataset. This will split the data in training, test and validation folders, tokenize them and save the arrow files in `processed` folder.

```bash
docker run --rm -v ${TARGET_PATH}:/workspace ${DOCKER_IMAGE_NAME}:${TAG} -v /workspace:${TARGET_PATH} python3 1.tokenize_uniref_csv.py --input_dir ${TARGET_PATH}/csv --output_dir ${TARGET_PATH}/processed
```

## 6. DDP

Now we are ready to submit distributed training jobs to pretrain ESM2 models. We provide the train-esm.slurm script to run training on 2 p5.48xlarge nodes with 8xH100 80 GB GPUs. Make sure data paths and model configuration is correct if you are running on custom data. To kick off distributed training execute:

sbatch train_ddp.sh

## 7. FSDP

sbatch train_fsdp.sh