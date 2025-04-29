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
export TARGET_PATH=/fsx/ubuntu/esm-slurm
export DOCKER_IMAGE_NAME=esm-slurm
export TAG=aws
#use a model that would be appropriate for compute nodes
export MODEL=facebook/esm2_t36_3B_UR50D
```

## 2. Build Docker Image

We provide an AWS optimized Docker image built file that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly.
To initiate container image build, run the following command:

```bash
./build.sh
---
 => [internal] load build definition from Dockerfile                                                                                                     0.0s
 => => transferring dockerfile: 710B                                                                                                                     0.0s
 => [internal] load metadata for nvcr.io/nvidia/pytorch:25.02-py3  
...
 => [internal] load build context                                                                                                                        0.0s
 => => transferring context: 47.75kB                                                                                                                     0.0s
 => [2/6] COPY train.py /workspace                                                                                                                      15.8s
 => [3/6] COPY 0.download_data.py /workspace                                                                                                             0.0s
 => [4/6] COPY 1.tokenize_uniref_csv.py /workspace                                                                                                       0.0s
 => [5/6] COPY requirements.txt /workspace                                                                                                               0.0s
 => [6/6] RUN pip install -r requirements.txt                                                                                                           41.9s
 => exporting to image                                                                                                                                   1.5s
 => => exporting layers                                                                                                                                  1.5s
 => => writing image sha256:6ef0e285fe3b6d0c81902976b4ba3743a47dfd1523346e997647cab43444f559                                                             0.0s
 => => naming to docker.io/library/esm-slurm:aws    
```
We can check that newly built Docker image is available in the local file system:

```bash
docker image list
REPOSITORY   TAG       IMAGE ID       CREATED              SIZE
esm-slurm    aws       6ef0e285fe3b   About a minute ago   24.9GB
```

## 3. Build Enroot Image

[NVIDIA Enroot](https://github.com/NVIDIA/enroot) is a lightweight container runtime that allows users to run containerized applications without requiring full-fledged container engines like Docker. It is designed for HPC environments, particularly the Slurm Workload Manager. To convert Docker images to Enroot squash files, run the following script:

```bash
./enroot.sh
---
[INFO] Fetching image
9e55c640dba7f3a1f54a83f2b83557ddd1d371defbf6f39df3be312db558d967
[INFO] Extracting image content...
...
Parallel mksquashfs: Using 16 processors
Creating 4.0 filesystem on /fsx/ubuntu/esm-slurm/esm-slurm.sqsh, block size 131072.
[=======================================================================================================================================/] 389448/389448 100%

Exportable Squashfs 4.0 filesystem, lzo compressed, data block size 131072
        uncompressed data, uncompressed metadata, uncompressed fragments,
        uncompressed xattrs, uncompressed ids
        duplicates are not removed
Filesystem size 23777760.23 Kbytes (23220.47 Mbytes)
        99.92% of uncompressed filesystem size (23795682.16 Kbytes)
Inode table size 9225730 bytes (9009.50 Kbytes)
        100.00% of uncompressed inode table size (9225730 bytes)
Directory table size 8139303 bytes (7948.54 Kbytes)
        100.00% of uncompressed directory table size (8139303 bytes)
No duplicate files removed
Number of inodes 262919
Number of files 228388
Number of fragments 18184
Number of symbolic links  1903
Number of device nodes 0
Number of fifo nodes 0
Number of socket nodes 0
Number of directories 32628
Number of ids (unique uids + gids) 1
Number of uids 1
        root (0)
Number of gids 1
        root (0)
```
We can also confirm that target file `esm-slurm.sqsh` is there in the shared directory:

```bash
ls -al $TARGET_PATH
-rw-r--r--  1 ubuntu ubuntu 24348430336 Apr 29 19:28 esm-slurm.sqsh
```

## 4. Prepare dataset

Next we need to download the [Uniref50](https://huggingface.co/datasets/agemagician/uniref50) training data. You can do so by running the following command using the image previously built:

```bash
docker run --rm -v ${TARGET_PATH}:/workspace ${DOCKER_IMAGE_NAME}:${TAG} -v /workspace:${TARGET_PATH} python3 0.download_data.py --output_dir ${TARGET_PATH}
----
=============
== PyTorch ==
=============

NVIDIA Release 25.02 (build 143088496)
PyTorch Version 2.7.0a0+ecf3bae
Container image Copyright (c) 2025, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
Copyright (c) 2014-2024 Facebook Inc.
Copyright (c) 2011-2014 Idiap Research Institute (Ronan Collobert)
...
Copyright (c) 2015      Yangqing Jia
Copyright (c) 2013-2016 The Caffe contributors
All rights reserved.

Various files include modifications (c) NVIDIA CORPORATION & AFFILIATES.  All rights reserved.

This container image and its contents are governed by the NVIDIA Deep Learning Container License.
By pulling and using the container, you accept the terms and conditions of this license:
https://developer.nvidia.com/ngc/nvidia-deep-learning-container-license

WARNING: The NVIDIA Driver was not detected.  GPU functionality will not be available.
   Use the NVIDIA Container Toolkit to start this container with GPU support; see
   https://docs.nvidia.com/datacenter/cloud-native/ .

NOTE: The SHMEM allocation limit is set to the default of 64MB.  This may be
   insufficient for PyTorch.  NVIDIA recommends the use of the following flags:
   docker run --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 ...
...
```
That container executuion  should download the data and partitions the data in 50 .csv files into the folder contained in the ${TARGET_PATH} environment variable. The whole process should take less than 30 mins.

## 5. Convert CSVs to HuggingFace Dataset and Tokenize

Next we need to tokenize the dataset. This will split the data in training, test and validation folders, tokenize them and save the arrow files in `processed` folder.

```bash
docker run --rm -v ${TARGET_PATH}:/workspace ${DOCKER_IMAGE_NAME}:${TAG} -v /workspace:${TARGET_PATH} python3 1.tokenize_uniref_csv.py --input_dir ${TARGET_PATH}/csv --output_dir ${TARGET_PATH}/processed
```

## 6. DDP

Now we are ready to submit distributed training jobs to pretrain ESM2 models. We provide the train-esm.slurm script to run training on 2 p5.48xlarge nodes with 8xH100 80 GB GPUs. Make sure data paths and model configuration is correct if you are running on custom data. To kick off distributed training execute:
```bash
sbatch train_ddp.sh
```
## 7. FSDP
```bash
sbatch train_fsdp.sh
```
