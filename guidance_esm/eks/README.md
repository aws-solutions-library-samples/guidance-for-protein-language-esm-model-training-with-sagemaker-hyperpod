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
8957193it [08:17, 686030.19it/s]04/18/2025 22:13:06 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x137.csv
69290910it [08:18, 139067.03it/s]
04/18/2025 22:13:07 - INFO - Writing 290910 records to /fsx-shared/esm/csv/x138.csv
04/18/2025 22:13:09 - INFO - Save complete
```
We can valildate contents of the shared directory `fsx-shared/esm` using the provided `view-fsx.yaml` deployment descriptor:

```bash
kubectl apply -f view-fsx.yaml
pod/fsx-share-test created
```
Then we can get "inside" that pod and review contents of the shared folder:
```bash
ubectl exec -it fsx-share-test -- /bin/bash
root@fsx-share-test:/# ls -ltr /fsx-shared/esm/csv
total 20538966
-rw-r--r-- 1 root root  160442718 Apr 18 22:09 x043.csv
-rw-r--r-- 1 root root  157890712 Apr 18 22:09 x044.csv
-rw-r--r-- 1 root root  155384478 Apr 18 22:09 x045.csv
-rw-r--r-- 1 root root  152885989 Apr 18 22:09 x046.csv
-rw-r--r-- 1 root root  150458014 Apr 18 22:09 x047.csv
...
- rw-r--r-- 1 root root  168375903 Apr 18 22:19 x040.csv
-rw-r--r-- 1 root root  165337183 Apr 18 22:19 x041.csv
-rw-r--r-- 1 root root  163011902 Apr 18 22:19 x042.csv
```


## 5. Convert CSVs to HuggingFace Dataset and Tokenize

Next we need to tokenize the dataset in order to provide training data in the specified format. This will split the data in training, test and validation folders, tokenize them and save the arrow files in `processed` folder.

```bash
cat preprocess-template.yaml | envsubst > preprocess-data.yaml
cat preprocess-data.yaml
apiVersion: v1
kind: Pod
metadata:
  name: preprocess-data
spec:
  containers:
  - name: preprocess-data
    image: 354918380621.dkr.ecr.us-east-1.amazonaws.com/esm:aws
    command: ["/bin/bash"]
    args: ["-c", "python3 1.tokenize_uniref_csv.py --input_dir /fsx-shared/esm/csv --output_dir /fsx-shared/esm/processed"]
    volumeMounts:
    - name: volume
      mountPath: /fsx-shared
  volumes:
  - name: volume
    persistentVolumeClaim:
      claimName: fsx-claim
```
Then initiate pre-processing job using generated deployment descriptor:

```bash
kubectl apply -f preprocess-data.yaml
pod/preprocess-data created
```
You can check the progress of data pre-processing by tailing that pod's log:
```bash
kubectl logs -f preprocess-data
ubectl logs -f preprocess-data
04/18/2025 22:34:40 - INFO - Parsing arguments
04/18/2025 22:34:40 - INFO - Loading csv files from /fsx-shared/esm/csv
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 12503.72files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 16833.33files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 6349.13files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 7265.66files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 16677.15files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 11445.95files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 14586.06files/s]
Downloading data:   0%|          | 0/18 [00:00<?, ?files/s]
...
enerating train split: 69290910 examples [00:44, 1557792.45 examples/s]
04/18/2025 22:54:24 - INFO - DatasetDict({
    train: Dataset({
        features: ['text'],      | 0/18 [00:00<?, ?files/s]
        num_rows: 69290910
    })
})
04/18/2025 22:54:24 - INFO - Splitting dataset
Flattening the indices: 100%|██████████| 10000000/10000000 [01:20<00:00, 124103.85 examples/s]
Flattening the indices: 100%|██████████| 50000/50000 [00:00<00:00, 115540.92 examples/s]
Flattening the indices: 100%|██████████| 50000/50000 [00:00<00:00, 114766.42 examples/s]
04/18/2025 22:55:51 - INFO - Saving splits to csv

```
To review the status of data tokenization using the same `fsx-share-test` pod used in porevios step:

```bash
kubectl exec -it fsx-share-test -- /bin/bash
ls -ltr /fsx-shared/esm/processed/csv
total 98
drwxr-xr-x 2 root root 33280 Apr 18 22:38 train
drwxr-xr-x 2 root root 33280 Apr 18 22:39 val
drwxr-xr-x 2 root root 33280 Apr 18 22:39 test
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
