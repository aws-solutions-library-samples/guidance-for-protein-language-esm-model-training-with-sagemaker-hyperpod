# Train Evolutionary Scale Models (ESM) with BioNemo

[NVIDIA BioNeMo](https://docs.nvidia.com/bionemo-framework/latest/) is a domain-specific machine learning framework for training and using foundation models for biology. This includes models for analyzing proteins, small molecules, and other biological molecules. To see the latest models available in BioNeMo 2.5 see [here](https://docs.nvidia.com/bionemo-framework/latest/models/).

This guidance provides step by step instructions to pretrain [ESM2](https://docs.nvidia.com/bionemo-framework/latest/models/ESM-2/) models with NVIDIA BioNeMo on Sagemaker HyPerPod slurm clusters.

## 0. Prerequisites

Have a slurm based Sagemaker HyperPod cluster with Nvidia GPUs.

## 1. Setup environment variables

SSH into the head or login node of your cluster and run:

```
# Path to save training data and checkpoints
export TARGET_PATH=/fsx/ubuntu/bionemo
export DOCKER_IMAGE_NAME=bionemo-slurm
export TAG=aws
```
Or source the `env.conf` file like:

```bash
source ./env.conf
```

## 2. Clone this GitHub repository

```bash
cd ${TARGET_PATH}
git clone https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework.git
```
Change permissions for `.sh` scripts for executable:
```bash
cd guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework/source/hyperpod_slurm
chmod 777 *.sh
```

## 3. Build Docker Image for BioNemo 

We provide the Dockerfile for an AWS optimized Docker image that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly:

```bash
./build.sh
----
[+] Building 171.3s (3/21)                                                                                                                    docker:default
 => [ 1/18] FROM nvcr.io/nvidia/clara/bionemo-framework:2.5@sha256:fbd1393898db19a6f252ba962b768efa24ae2baea6a4b98d7a806d20f47318a3                   169.9s
 => => sha256:3e24a9b58eb740310a7c47d91afc44b39933c1f5d664457d2328ecf71572b576 13.29MB / 13.29MB                                                       51.6s
 => => sha256:9bc6c0fa41196d6a8763a9276fc7ddd6ba28427f13ab367f54c1381e2aadace5 41.53MB / 41.53MB                                                       53.7s
 => => sha256:56ec118b57b4afac941caf3d82bd1a78e7d67f4be83c709fc7509a50760f515e 7.50MB / 7.50MB                                                         54.8s
 => => sha256:badb1b86efce008a5a42855c600c113400e32dd44c85e530af9d712038d9ecb0 186.80MB / 186.80MB                                                     59.1s
 => => sha256:890830e955ecb8e9bf16ac99810c435bb1e247dd0599180901affe3850ae0807 6.78kB / 6.78kB            
....
=> [13/18] RUN echo "hwloc_base_binding_policy = none" >> /opt/amazon/openmpi/etc/openmpi-mca-params.conf  && echo "rmaps_base_mapping_policy = slot"  0.3s
 => [14/18] RUN pip3 install awscli pynvml wandb                                                                                                       17.5s
 => [15/18] RUN mv /opt/amazon/openmpi/bin/mpirun /opt/amazon/openmpi/bin/mpirun.real  && echo '#!/bin/bash' > /opt/amazon/openmpi/bin/mpirun  && echo  0.3s
 => [16/18] WORKDIR /workspace/bionemo2/sub-packages/bionemo-esm2                                                                                       0.0s
 => [17/18] RUN pip install -e .                                                                                                                       69.8s
 => [18/18] WORKDIR /workspace                                                                                                                          0.0s
 => exporting to image                                                                                                                                  3.1s
 => => exporting layers                                                                                                                                 3.1s
 => => writing image sha256:0fb34e775d5c39753457404bed0df3afc6cea697bf1c6cd81f4dbc2727c15130                                                            0.0s
 => => naming to docker.io/library/bionemo-slurm:aws     
```

## 4. Build Enroot Image

[NVIDIA Enroot](https://github.com/NVIDIA/enroot) is a lightweight container runtime that allows users to run containerized applications without requiring full-fledged container engines like Docker. It is designed for HPC environments, particularly the Slurm Workload Manager. To convert Docker images to Enroot squash files:

```bash
./enroot.sh
----
Preparing  image  /fsx/ubuntu/bionemo/bionemo-slurm.sqsh ..
[INFO] Fetching image

0a9076bddd8d23a16471bc48d0ee58a3960e70be34e820e3e09fd8dfae5e5222
[INFO] Extracting image content...
Parallel mksquashfs: Using 16 processors
Creating 4.0 filesystem on /fsx/ubuntu/bionemo/bionemo-slurm.sqsh, block size 131072.
...
Number of socket nodes 0
Number of directories 36828
Number of ids (unique uids + gids) 1
Number of uids 1
        root (0)
Number of gids 1
        root (0)
```

## 5. Download data

BioNeMo 2.5 container provides a CLI `download_bionemo_data` to download test or full UniProt dataset from NVIDIA Catalog which we can run as below. `get-data.sh` runs a container based on the Docker image created above, runs the `download_bionemo_data` CLI to download test data and kills the container when done and saves `_sanity.tar.gz` compressed file (71M) and `_sanity.tar.gz.untar` (134M) with training and validation data.

```bash
./get-data.sh
---
============
== PyTorch ==
=============

NVIDIA Release 25.01 (build 134983853)
PyTorch Version 2.6.0a0+ecf3bae
Container image Copyright (c) 2025, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
Copyright (c) 2014-2024 Facebook Inc.
Copyright (c) 2011-2014 Idiap Research Institute (Ronan Collobert)
...
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

Downloading data from 'nvidia/clara/esm2_pretrain_nemo2_testdata:1.0' to file '/root/.cache/bionemo/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz'.
{
    "download_end": "2025-05-07 23:24:09",
    "download_start": "2025-05-07 23:23:56",
    "download_time": "13s",
    "files_downloaded": 1,
    "local_path": "/root/.cache/bionemo/tmpc1vrxrpn/esm2_pretrain_nemo2_testdata_v1.0",
    "size_downloaded": "69.91 MB",
    "status": "COMPLETED"
}
Untarring contents of '/root/.cache/bionemo/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz' to '/root/.cache/bionemo/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar'
/root/.cache/bionemo/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar
```

## 6. Pretrain ESM2 models

Now we are ready to submit distributed training jobs to pretrain ESM-2 models. We provide the `train-esm.slurm` script to run training on HyperPod compute nodes with respective GPU resources. Make sure data paths and model configuration is correct if you are running on custom data. 

Modify the `train-esm.slurm` script according to the actual GPU and EFA cluster resources 

To kick off distributed BioNemo model training, execute the following command:

```bash
sbatch train-esm.slurm
Submitted batch job 1
```
To check the status of submitted job, run the following command:
```bash
squeue
JOBID PARTITION     NAME     USER   ST       TIME  NODES NODELIST(REASON)
      2     dev   train-es   ubuntu  R       0:07      2 ip-10-1-0-96,ip-10-1-39-225
```
Once training job starts you should see logs as `tail -f slurm-esm2-train-xx.out`:

```
0: Training epoch 0, iteration 28/99 | lr: 5.6e-06 | global_batch_size: 32 | global_step: 28 | reduced_train_loss: 2.778 | train_step_timing in s: 0.189 | consumed_samples: 928 | val_loss: 2.861 | val_ppl: 17.57
 0: Training epoch 0, iteration 29/99 | lr: 5.8e-06 | global_batch_size: 32 | global_step: 29 | reduced_train_loss: 2.782 | train_step_timing in s: 0.1903 | consumed_samples: 960 | val_loss: 2.861 | val_ppl: 17.57
 0: Training epoch 0, iteration 30/99 | lr: 6e-06 | global_batch_size: 32 | global_step: 30 | reduced_train_loss: 2.709 | train_step_timing in s: 0.1915 | consumed_samples: 992 | val_loss: 2.861 | val_ppl: 17.57
 0: Training epoch 0, iteration 31/99 | lr: 6.2e-06 | global_batch_size: 32 | global_step: 31 | reduced_train_loss: 2.803 | train_step_timing in s: 0.1894 | consumed_samples: 1024 | val_loss: 2.861 | val_ppl: 17.57
 0: Training epoch 0, iteration 32/99 | lr: 6.4e-06 | global_batch_size: 32 | global_step: 32 | reduced_train_loss: 2.886 | train_step_timing in s: 0.1921 | consumed_samples: 1056 | val_loss: 2.861 | val_ppl: 17.57
 0: Training epoch 0, iteration 33/99 | lr: 6.6e-06 | global_batch_size: 32 | global_step: 33 | reduced_train_loss: 2.791 | train_step_timing in s: 0.1893 | consumed_samples: 1088 | val_loss: 2.861 | val_ppl: 17.57
 0: Training epoch 0, iteration 34/99 | lr: 6.8e-06 | global_batch_size: 32 | global_step: 34 | reduced_train_loss: 2.788 | train_step_timing in s: 0.1902 | consumed_samples: 1120 | val_loss: 2.861 | val_ppl: 17.57
```

Once training is done, you should see checkpoints stored in `${TARGET_PATH}/esm2` folder.
