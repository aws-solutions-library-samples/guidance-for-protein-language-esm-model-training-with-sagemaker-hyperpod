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
export DOCKER_IMAGE_NAME=bionemo
```

## 2. Pull this github repo

```bash
cd ${TARGET_PATH}
git clone https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework.git

cd guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework/source/hyperpod_slurm
chmod 777 *.sh
```

## 3. Build Docker Image

We provide an AWS optimized Docker image that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly:

```bash
./build.sh
```

## 4. Build Enroot Image

[NVIDIA Enroot](https://github.com/NVIDIA/enroot) is a lightweight container runtime that allows users to run containerized applications without requiring full-fledged container engines like Docker. It is designed for HPC environments, particularly the Slurm Workload Manager. To convert Docker images to Enroot squash files:

```bash
./enroot.sh
```

## 5. Download data

BioNeMo 2.5 container provides a CLI `download_bionemo_data` to download test or full UniProt dataset from NVIDIA Catalog which we can run as below. `get-data.sh` runs a container based on the Docker image created above, runs the `download_bionemo_data` CLI to download test data and kills the container when done and saves `_sanity.tar.gz` compressed file (71M) and `_sanity.tar.gz.untar` (134M) with training and validation data.

```bash
./get-data.sh
```

## 6. Pretrain ESM2 models

Now we are ready to submit distributed training jobs to pretrain `ESM2` models. We provide the `train-esm.slurm` script to run training on 2 `p5.48xlarge` nodes with `8xH100 80 GB` GPUs. Make sure data paths and model configuration is correct if you are running on custom data. To kick off distributed training execute:

```bash
sbatch train-esm.slurm

```

Once training starts you should see logs as `tail -f slurm-esm2-train-xx.out`:

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