#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

###SBATCH --nodes=2 # number of nodes to use
#SBATCH --nodes=${NUM_NODES} 
#SBATCH --gpus-per-node=1
#SBATCH --job-name=esm2-ddp # name of your job
#SBATCH --output=esm2-ddp-%x.%j.out
#SBATCH --exclusive # job has exclusive use of the resource, no sharing

set -ex;

###########################
###### User Variables #####
###########################

#GPUS_PER_NODE=1 # 4 for G5.12x, 8 for P4/P5
GPUS_PER_NODE=${GPU_PER_NODE}

IMAGE=${TARGET_PATH}/${DOCKER_IMAGE_NAME}.sqsh
###########################
## Environment Variables ##
###########################

## Plenty of EFA level variables
## Comment out for non-efa instances (G4d, P3)
## For G5.12x, Comment out RDMA and Fork safe
## For G4dn and other G5, comment out all

export FI_PROVIDER=efa
export NCCL_DEBUG=INFO


###########################
####### Torch Dist  #######
###########################

declare -a TORCHRUN_ARGS=(
    --nproc_per_node=$GPUS_PER_NODE
    --nnodes=$SLURM_JOB_NUM_NODES
    --rdzv_id=$SLURM_JOB_ID
    --rdzv_backend=c10d
    --rdzv_endpoint=$(hostname)
)
export TRAIN_SCRIPT=/workspace/train.py

############################
#ESM Training Params ##
############################

declare -a TRAINING_ARGS=(
    --config_name ${MODEL} \
    --dataloader_num_workers 2 \
    --bf16 True \
    --do_eval True \
    --do_preprocess False \
    --do_train True \
    --gradient_accumulation_steps 1 \
    --logging_steps 16 \
    --num_train_epochs 1 \
    --output_dir ${TARGET_PATH}/out-ddp \
    --per_device_train_batch_size 4 \
    --max_train_samples 100000 \
    --tokenizer_name ${MODEL} \
    --dataset_dir ${TARGET_PATH}/processed/arrow \
    --torch_compile True \
    --pad_to_max_length True \
    --max_seq_length 512 \
    --ddp_bucket_cap_mb 125
)

AUTO_RESUME=""
if [ -d "/opt/sagemaker_cluster" ]; then
    echo "Detected Hyperpod cluster.. enabling --auto-resume=1"
    AUTO_RESUME="--auto-resume=1"
fi

declare -a ARGS=(
    --container-image ${IMAGE}
    --container-mount-home
    --container-mounts /fsx/ubuntu:/fsx/ubuntu
    --no-container-remap-root
)

srun "${ARGS[@]}" ${AUTO_RESUME} -l torchrun "${TORCHRUN_ARGS[@]}" $TRAIN_SCRIPT "${TRAINING_ARGS[@]}"
