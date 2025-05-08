#!/bin/bash
#SBATCH --nodes=2                    # number of HyperPod compute nodes
#SBATCH --ntasks-per-node=1          # n tasks per machine (one task per gpu) <required>
#SBATCH --exclusive                  # exclusive node access
#SBATCH --output bionemo-esm2-train-%j.out

export FI_PROVIDER=efa
export NCCL_DEBUG=INFO

###########################
###### User Variables #####
###########################

# default variables for Enroot
: "${IMAGE:=${DATA_HOME_DIR}/bionemo.sqsh}"
: "${DATA_PATH:=/fsxl}"
: "${FSX_MOUNT:=$DATA_PATH:$DATA_PATH}"

#arguments for srun command 
declare -a ARGS=(
    --container-image $IMAGE
    --container-mount-home
    --container-mounts ${DATA_HOME_DIR}:${DATA_HOME_DIR}
)


AUTO_RESUME=""
if [ -d "/opt/sagemaker_cluster" ]; then
    echo "Detected Hyperpod cluster.. enabling --auto-resume=1"
    AUTO_RESUME="--auto-resume=1"
fi


# Enable fused attention in transformer engine for speed-up
DATA_DIR=$(find ${TARGET_PATH} -type d -name "*untar*" -print -quit)
echo "DATA_DIR is ${DATA_DIR}..."

srun -l "${ARGS[@]}"  python3 /workspace/bionemo2/sub-packages/bionemo-esm2/src/bionemo/esm2/scripts/train_esm2.py \
    --train-cluster-path ${DATA_DIR}/2024_03_sanity/train_clusters_sanity.parquet \
    --train-database-path ${DATA_DIR}/2024_03_sanity/train_sanity.db \
    --valid-cluster-path ${DATA_DIR}/2024_03_sanity/valid_clusters.parquet \
    --valid-database-path ${DATA_DIR}/2024_03_sanity/validation.db \
    --precision="bf16-mixed" \
    --num-gpus $SLURM_NTASKS_PER_NODE \
    --num-nodes $SLURM_NNODES \
    --num-steps 100 \
    --val-check-interval 25 \
    --max-seq-length 1024 \
    --limit-val-batches 2 \
    --micro-batch-size 2 \
    --num-layers 33 \
    --hidden-size 1280 \
    --num-attention-head 20 \
    --ffn-hidden-size 5120 \
    --tensor-model-parallel-size 1 \
    --create-tensorboard-logger \
    --result-dir ${TARGET_PATH}
