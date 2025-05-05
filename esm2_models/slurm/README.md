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
.....
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
docker run -v ${TARGET_PATH}:/data  ${DOCKER_IMAGE_NAME}:${TAG}  python3 0.download_data.py --output_dir /data
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

04/30/2025 19:15:29 - INFO - Generating csv files
Reading FASTA file
498366it [00:12, 59214.38it/s]04/30/2025 19:15:41 - INFO - Writing 500000 records to /data/csv/x000.csv
996173it [00:51, 78288.46it/s]04/30/2025 19:16:21 - INFO - Writing 500000 records to /data/csv/x001.csv
1491434it [01:15, 89203.73it/s]04/30/2025 19:16:45 - INFO - Writing 500000 records to /data/csv/x002.csv
...
68949448it [13:11, 541961.50it/s]04/30/2025 19:28:41 - INFO - Writing 500000 records to /data/csv/x137.csv
69488478it [13:13, 87610.77it/s] 
04/30/2025 19:28:42 - INFO - Writing 488478 records to /data/csv/csv/x138.csv
04/30/2025 19:28:44 - INFO - Save complete
```

That container execution should download the Uniref 50 training data as 50 .csv formatted files into the folder derived from ${TARGET_PATH}/csv environment variable. The whole process should take less than 30 mins.

To confirm that the dataset files are indeed saved to that directory, we can run the following command:
```bash
ls -al  $TARGET_PATH/csv
total 20594019
drwxr-xr-x 3 root   root        41472 Apr 30 19:46 .
drwxrwxr-x 3 ubuntu ubuntu      33280 Apr 30 19:10 ..
-rw-r--r-- 1 root   root   1338965519 Apr 30 20:02 x000.csv
-rw-r--r-- 1 root   root    739136803 Apr 30 20:03 x001.csv
-rw-r--r-- 1 root   root    608770034 Apr 30 20:03 x002.csv
-rw-r--r-- 1 root   root    537187950 Apr 30 20:03 x003.csv
-rw-r--r-- 1 root   root    487469687 Apr 30 20:03 x004.csv
-rw-r--r-- 1 root   root    449800266 Apr 30 20:04 x005.csv
-rw-r--r-- 1 root   root    419801146 Apr 30 20:04 x006.csv
-rw-r--r-- 1 root   root    395810836 Apr 30 20:04 x007.csv
-rw-r--r-- 1 root   root    375021260 Apr 30 20:04 x008.csv
-rw-r--r-- 1 root   root    357140420 Apr 30 20:05 x009.csv
-rw-r--r-- 1 root   root    341566749 Apr 30 20:05 x010.csv
-rw-r--r-- 1 root   root    327643505 Apr 30 20:05 x011.csv
-rw-r--r-- 1 root   root    315227208 Apr 30 20:05 x012.csv
...
-rw-r--r-- 1 root   root     29808230 Apr 30 20:15 x137.csv
-rw-r--r-- 1 root   root     23821111 Apr 30 20:15 x138.csv
```

## 5. Convert CSVs to HuggingFace Dataset and Tokenize

Next we need to tokenize the downloaded dataset. This will split the data in `training`, `test` and `validation` folders, tokenize them and save the "arrow" files in `processed` folder.

```bash
docker run --rm -v ${TARGET_PATH}:/data ${DOCKER_IMAGE_NAME}:${TAG} /bin/bash -c "python3 1.tokenize_uniref_csv.py --input_dir /data/csv --output_dir /data/processed"
----
05/02/2025 20:47:00 - INFO - Parsing arguments
05/02/2025 20:47:00 - INFO - Loading csv files from /data/csv
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 11694.16files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 18048.64files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 10751.56files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 23038.59files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 32486.00files/s]
...
Saving the dataset (62/62 shards): 100%|██████████| 10000000/10000000 [02:10<00:00, 76357.10 examples/s]
Saving the dataset (1/1 shards): 100%|██████████| 50000/50000 [00:00<00:00, 54862.74 examples/s]
Saving the dataset (1/1 shards): 100%|██████████| 50000/50000 [00:00<00:00, 54984.57 examples/s]
```

## 6. Training Using DDP Framework

Now we are ready to submit distributed training jobs to pretrain ESM2 models. We provide the `train-ddp.ssh` batch script to initualize PyTorch training job basd on DDP framework on cluster compute nodes (e.g. `ml.g5.8xlarge`) with certain parameters for GPUs and EFSs . Make sure data paths and model configuration is correct if you are running on custom data. 

To kick off distributed training job execute:
```bash
sbatch train_ddp.sh
```

To verify that the training jobs are running on requested number of HyperPod nodes, run the following command: 
```bash
squeue
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
1       dev  esm2-ddp   ubuntu  R       0:07      2 ip-10-1-29-[105,166]
```


If you need to follow the training process output, we can run a command like against the .OUT file
```bash
tail -f <esm2-ddp-esm2-ddp.N.out>
---
[INFO     | __main__           ]: *** Evaluate ***
0: [INFO|trainer.py:805] 2025-05-02 21:39:49,138 >> The following columns in the evaluation set don't have a corresponding argument in `EsmForMaskedLM.forward` and have been ignored: special_tokens_mask. If special_tokens_mask are not expected by `EsmForMaskedLM.forward`,  you can safely ignore this message.
0: [INFO|trainer.py:3788] 2025-05-02 21:39:49,140 >> 
0: ***** Running Evaluation *****
0: [INFO|trainer.py:3790] 2025-05-02 21:39:49,140 >>   Num examples = 50000
0: [INFO|trainer.py:3793] 2025-05-02 21:39:49,140 >>   Batch size = 8
  3%|▎         | 98/3125 [00:02<01:04, 46.87it/s]
  6%|▋         | 198/3125 [00:04<01:02, 46.85it/s]
  9%|▉         | 293/3125 [00:06<01:00, 46.74it/s]
 12%|█▏        | 388/3125 [00:08<00:58, 46.69it/s]
 15%|█▌        | 483/3125 [00:10<00:56, 46.56it/s]
 18%|█▊        | 573/3125 [00:12<00:55, 46.35it/s]
 21%|██▏       | 668/3125 [00:14<00:53, 46.29it/s]
 24%|██▍       | 758/3125 [00:16<00:51, 46.11it/s]
 27%|██▋       | 848/3125 [00:18<00:49, 46.08it/s]
 30%|███       | 938/3125 [00:20<00:47, 45.93it/s]
 33%|███▎      | 1023/3125 [00:22<00:45, 45.91it/s]
...
 91%|█████████ | 2833/3125 [01:02<00:06, 43.71it/s]
 93%|█████████▎| 2903/3125 [01:04<00:05, 43.62it/s]
 95%|█████████�| 2973/3125 [01:05<00:03, 43.55it/s]
 98%|█████████▊| 3048/3125 [01:07<00:01, 43.45it/s]
100%|█████████▉| 3118/3125 [01:09<00:00, 43.44it/s]
1: [INFO     | __main__           ]: Metrics are {'eval_loss': 2.6093177795410156, 'eval_accuracy': 0.20685649827919567, 'eval_runtime': 75.8886, 'eval_samples_per_second': 658.86, 'eval_steps_per_second': 41.179, 'epoch': 1.0}
1: [INFO     | __main__           ]: Calculating perplexity
1: [INFO     | __main__           ]: Perplexity: 13.589776465064947
100%|██████████| 3125/3125 [01:16<00:00, 41.02it/s]
0: [INFO     | __main__           ]: Metrics are {'eval_loss': 2.6093177795410156, 'eval_accuracy': 0.20685649827919567, 'eval_runtime': 76.5074, 'eval_samples_per_second': 653.532, 'eval_steps_per_second': 40.846, 'epoch': 1.0}
0: [INFO     | __main__           ]: Calculating perplexity
0: [INFO     | __main__           ]: Perplexity: 13.589776465064947
0: ***** eval metrics *****
0:   epoch                   =        1.0
0:   eval_accuracy           =     0.2069
0:   eval_loss               =     2.6093
0:   eval_runtime            = 0:01:16.50
0:   eval_samples            =      50000
0:   eval_samples_per_second =    653.532
0:   eval_steps_per_second   =     40.846
0:   perplexity              =    13.5898
```
To validate that model was indeed trained we can run the following command in the output directory:

```bash
/esm-slurm/out-ddp$ cat all_results.json 
{
    "epoch": 1.0,
    "eval_accuracy": 0.20685649827919567,
    "eval_loss": 2.6093177795410156,
    "eval_runtime": 76.5074,
    "eval_samples": 50000,
    "eval_samples_per_second": 653.532,
    "eval_steps_per_second": 40.846,
    "perplexity": 13.589776465064947,
    "total_flos": 2304587980013568.0,
    "train_loss": 2.6276449169921876,
    "train_runtime": 439.0884,
    "train_samples": 100000,
    "train_samples_per_second": 227.745,
    "train_steps_per_second": 28.468
}
```
That confirms that model training was completed successfully with DDP framework

## 7. Training Using FSDP Framework

Now we are ready to submit distributed training jobs to pretrain ESM2 models. We provide the `train-fsdp.ssh` batch script to initualize PyTorch training job basd on FSDP framework on cluster compute nodes (e.g. `ml.g5.8xlarge`) with certain parameters for GPUs and EFSs . Make sure data paths and model configuration is correct if you are running on custom data. 

```bash
sbatch train_fsdp.sh
```
To verify that the training jobs are running on requested number of HyperPod nodes, run the following command: 
```bash
squeue
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
1       dev  esm2-fsdp   ubuntu  R       0:07      2 ip-10-1-29-[105,166]
```

An output of such command should be like shown below:

If you want to follow the output of FSDP training job, you can run a command like:
```bash
ail -f esm2-fsdp-esm2-fsdp.20.out
1: [INFO|trainer.py:2134] 2025-05-02 22:42:34,741 >>   Total train batch size (w. parallel, distributed & accumulation) = 88
1: [INFO|trainer.py:2135] 2025-05-02 22:42:34,741 >>   Gradient Accumulation steps = 11
1: [INFO|trainer.py:2136] 2025-05-02 22:42:34,741 >>   Total optimization steps = 1,136
1: [INFO|trainer.py:2137] 2025-05-02 22:42:34,742 >>   Number of trainable parameters = 3,920,390
1: ip-10-1-40-172:48007:48141 [0] NCCL INFO Connected binomial trees
0: ip-10-1-39-225:48124:48261 [0] NCCL INFO Connected binomial trees
0: {'loss': 3.0288, 'grad_norm': 1.4424070119857788, 'learning_rate': 4.929577464788733e-05, 'epoch': 0.01}
  2%|▏         | 18/1136 [00:08<08:31,  2.19it/s]
0: {'loss': 2.8485, 'grad_norm': 3.385751724243164, 'learning_rate': 4.8591549295774653e-05, 'epoch': 0.03}
  3%|▎         | 35/1136 [00:16<08:18,  2.21it/s]
0: {'loss': 2.7659, 'grad_norm': 1.916214942932129, 'learning_rate': 4.788732394366197e-05, 'epoch': 0.04}
  5%|▍         | 53/1136 [00:24<08:10,  2.21it/s]
0: {'loss': 2.7257, 'grad_norm': 2.18135142326355, 'learning_rate': 4.71830985915493e-05, 'epoch': 0.06}
  6%|▋         | 71/1136 [00:32<07:59,  2.22it/s]]
0: {'loss': 2.708, 'grad_norm': 2.5152652263641357, 'learning_rate': 4.647887323943662e-05, 'epoch': 0.07}
  8%|▊         | 89/1136 [00:40<07:55,  2.20it/s]
0: {'loss': 2.7009, 'grad_norm': 1.8158063888549805, 'learning_rate': 4.577464788732395e-05, 'epoch': 0.08}
  9%|▉         | 106/1136 [00:48<07:43,  2.22it/s]
...
0: {'loss': 2.6211, 'grad_norm': 0.8737764954566956, 'learning_rate': 1.4084507042253521e-06, 'epoch': 0.97}
 98%|█████████▊| 1117/1136 [08:21<00:08,  2.25it/s]
0: {'loss': 2.6324, 'grad_norm': 0.726458728313446, 'learning_rate': 7.042253521126761e-07, 'epoch': 0.99}
 99%|███████�█▉| 1129/1136 [08:26<00:03,  2.25it/s]
0: {'loss': 2.6166, 'grad_norm': 0.8394569158554077, 'learning_rate': 0.0, 'epoch': 1.0}
100%|██████████| 1136/1136 [08:29<00:00,  2.25it/s]/usr/local/lib/python3.12/dist-packages/torch/distributed/fsdp/fully_sharded_data_parallel.py:690: FutureWarning: FSDP.state_dict_type() and FSDP.set_state_dict_type() are being deprecated. Please use APIs, get_state_dict() and set_state_dict(), which can support different parallelisms, FSDP1, FSDP2, DDP. API doc: https://pytorch.org/docs/stable/distributed.checkpoint.html#torch.distributed.checkpoint.state_dict.get_sta
0: te_dict .Tutorial: https://pytorch.org/tutorials/recipes/distributed_checkpoint_recipe.html .
0:   warnings.warn(
0: [INFO|trainer.py:3478] 2025-05-02 22:51:04,774 >> Saving model checkpoint to /fsx/ubuntu/esm-slurm/out-fsdp/checkpoint-1136
0: [INFO|configuration_utils.py:472] 2025-05-02 22:51:04,779 >> Configuration saved in /fsx/ubuntu/esm-slurm/out-fsdp/checkpoint-1136/config.json
0: [INFO|modeling_utils.py:2690] 2025-05-02 22:51:04,844 >> Model weights saved in /fsx/ubuntu/esm-slurm/out-fsdp/checkpoint-1136/model.safetensors
0: [INFO|tokenization_utils_base.py:2574] 2025-05-02 22:51:04,847 >> tokenizer config file saved in /fsx/ubuntu/esm-slurm/out-fsdp/checkpoint-1136/tokenizer_config.json
0: [INFO|tokenization_utils_base.py:2583] 2025-05-02 22:51:04,850 >> Special tokens file saved in /fsx/ubuntu/esm-slurm/out-fsdp/checkpoint-1136/special_tokens_map.json
1: [INFO|trainer.py:2383] 2025-05-02 22:51:05,095 >> 
1: 
1: Training completed. Do not forget to share your model on huggingface.co/models =)
```
To validate that model was indeed trained we can run the following command in the output directory:

```bash
/esm-slurm/out-fsdp$ cat all_results.json 
{
    "epoch": 0.99968,
    "eval_accuracy": 0.20331036132698413,
    "eval_loss": 2.628765344619751,
    "eval_runtime": 88.2792,
    "eval_samples": 50000,
    "eval_samples_per_second": 566.385,
    "eval_steps_per_second": 35.399,
    "perplexity": 13.856651147531753,
    "total_flos": 1151925283717120.0,
    "train_loss": 2.6576662063598633,
    "train_runtime": 510.4751,
    "train_samples": 100000,
    "train_samples_per_second": 195.896,
    "train_steps_per_second": 2.225
}
```
That confirms that ESM-2 model training was completed successfully with FSDP framework
