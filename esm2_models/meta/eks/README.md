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
    imagePullPolicy: Always

    command: ["/bin/bash"]
    args: ["-c", "python3 1.tokenize_uniref_csv.py --input_dir /fsx-shared/esm/csv --output_dir /fsx-shared/esm/processed"]
    env:
      - name: TRANSFORMERS_CACHE
        value: "/fsx-shared/.cache/models"
      - name: HF_DATASETS_CACHE
        value: "/fsx-shared/.cache/datasets"
      - name: HF_HOME
        value: "/fsx-shared/.cache/hfhome"
    volumeMounts:
    - name: volume
      mountPath: /fsx-shared
  volumes:
  - name: volume
    persistentVolumeClaim:
      claimName: fsx-claim
```
NOTE: use caching to avoid running out of storage space on smaller Compute nodes, as shown above

Then initiate pre-processing job using generated deployment descriptor:

```bash
kubectl apply -f preprocess-data.yaml
pod/preprocess-data created
```
You can check the progress of data pre-processing by tailing that pod's log:
```bash
usr/local/lib/python3.12/dist-packages/transformers/utils/hub.py:127: FutureWarning: Using `TRANSFORMERS_CACHE` is deprecated and will be removed in v5 of Transformers. Use `HF_HOME` instead.
  warnings.warn(
04/24/2025 18:47:49 - INFO - Parsing arguments
04/24/2025 18:47:49 - INFO - Loading csv files from /fsx-shared/esm/csv
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 11638.27files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 11164.96files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 9749.16files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 6409.50files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 7044.65files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 22462.80files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 98560.67files/s]
Generating train split: 69271261 examples [01:21, 850175.57 examples/s]
04/24/2025 18:49:17 - INFO - DatasetDict({
    train: Dataset({
        features: ['text'],
        num_rows: 69271261       | 0/18 [00:00<?, ?files/s]
    })
})
04/24/2025 18:49:17 - INFO - Splitting dataset
Flattening the indices: 100%|██████████| 10000000/10000000 [09:19<00:00, 17868.46 examples/s]
Flattening the indices: 100%|██████████| 50000/50000 [00:01<00:00, 41290.51 examples/s]
Flattening the indices: 100%|██████████| 50000/50000 [00:01<00:00, 33631.69 examples/s]
04/24/2025 18:58:45 - INFO - Saving splits to csv
Creating CSV from Arrow format: 100%|██████████| 10000/10000 [1:07:37<00:00,  2.46ba/s]
Creating CSV from Arrow format: 100%|██████████| 50/50 [00:21<00:00,  2.31ba/s]
Creating CSV from Arrow format: 100%|██████████| 50/50 [00:21<00:00,  2.30ba/s]
04/24/2025 20:07:06 - INFO - Processing line by line
Running tokenizer on dataset line_by_line (num_proc=8): 100%|██████████| 10000000/10000000 [19:22<00:00, 8600.75 examples/s]
Running tokenizer on dataset line_by_line (num_proc=8): 100%|██████████| 50000/50000 [00:04<00:00, 10157.73 examples/s]
Running tokenizer on dataset line_by_line (num_proc=8): 100%|██████████| 50000/50000 [00:05<00:00, 9801.23 examples/s]
Saving the dataset (62/62 shards): 100%|██████████| 10000000/10000000 [01:19<00:00, 125729.95 examples/s]
Saving the dataset (1/1 shards): 100%|██████████| 50000/50000 [00:00<00:00, 135181.52 examples/s]
Saving the dataset (1/1 shards): 100%|██████████| 50000/50000 [00:00<00:00, 105235.24 examples/s]
```

To review the status of data tokenization using the same `fsx-share-test` pod used in previous step, run the following command:

```bash
kubectl exec -it fsx-share-test  -- ls -ltr /fsx-shared/esm/processed/arrow/train
total 7126383
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00000-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00001-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00002-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00003-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00004-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00005-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00006-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00007-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00008-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00009-of-00062.arrow
-rw-r--r-- 1 root root 497488288 Apr 24 20:26 data-00010-of-00062.arrow
...
```

## 6. Training Using DDP Framework

Now we are ready to submit distributed training jobs to pretrain ESM2 models. We provide the `train-ddp-template.yaml` template to run training on  HyperPod cluster compute nodes with certain number of GPUs, per node specification. Make sure data paths and model configuration is correct if you are running on custom data set.

To kick off DDP based distributed training execute, we first need to generate specific training job manifest for K8s:

```bash
cat train-ddp-template.yaml | envsubst > train-ddp.yaml
cat train-ddp.yaml
apiVersion: v1
kind: Service
metadata:
  name: etcd
spec:
  ports:
    - name: etcd-client-port
      port: 2379
      protocol: TCP
      targetPort: 2379
  selector:
    app: etcd

---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: etcd
  name: etcd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: etcd
  template:
    metadata:
      labels:
        app: etcd
    spec:
      containers:
        - name: etcd
          command: ["/usr/local/bin/etcd"]
          args:
            - "--data-dir"
            - "/var/lib/etcd"
            - "--enable-v2"
            - "--listen-client-urls"
            - "http://0.0.0.0:2379"
            - "--advertise-client-urls"
            - "http://0.0.0.0:2379"
            - "--initial-cluster-state"
            - "new"
          image: quay.io/coreos/etcd:v3.5.19
          ports:
            - containerPort: 2379
              name: client
              protocol: TCP
            - containerPort: 2380
              name: server
              protocol: TCP
      restartPolicy: Always
---
apiVersion: "kubeflow.org/v1"
kind: PyTorchJob
metadata:
  name: esm2
spec:
  elasticPolicy:
    rdzvBackend: etcd
    rdzvHost: etcd
    rdzvPort: 2379
    minReplicas: 1
    maxReplicas: 64
    maxRestarts: 100
    metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 90
  pytorchReplicaSpecs:
    Worker:
      replicas: 4
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          tolerations:
            - key: nvidia.com/gpu
              operator: Exists
              effect: NoSchedule
          volumes:
          - name: fsx-pv-storage
            persistentVolumeClaim:
              claimName: fsx-claim
          containers:
            - name: pytorch
              image: 354918380621.dkr.ecr.us-east-1.amazonaws.com/esm:aws
              resources:
                requests:
                  nvidia.com/gpu: 1
                  vpc.amazonaws.com/efa: 1
                limits:
                  nvidia.com/gpu: 1
                  vpc.amazonaws.com/efa: 1
              env:
                - name: NCCL_DEBUG
                  value: "INFO"
              volumeMounts:
                - mountPath: /fsx-shared
                  name: fsx-pv-storage
              imagePullPolicy: Always
              command:
                - "torchrun"
                - --nproc_per_node=1
                - --nnodes=4
                - /workspace/train.py
                - --config_name=facebook/esm2_t6_8M_UR50D
                - --dataloader_num_workers=8
                - --bf16=True
                - --do_eval=True
                - --do_preprocess=False
                - --do_train=True
                - --gradient_accumulation_steps=1
                - --logging_steps=16
                - --num_train_epochs=1
                - --output_dir=/fsx-shared/esm
                - --per_device_train_batch_size=8
                - --max_train_samples=100000
                - --tokenizer_name=facebook/esm2_t6_8M_UR50D
                - --dataset_dir=/fsx-shared/esm/processed/arrow
                - --torch_compile=True
                - --pad_to_max_length=True
                - --max_seq_length=512
                - --ddp_bucket_cap_mb=125
```
To initiate training, run the following command generated PyTorchJob deployment descriptor

```bash
kubectl apply -f train-ddp.yaml
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/esm2 created
```
To validate status of the ESM-2 training job containers, run the following command (assuming they run in the `default` namespace):
```bash
kubectl get job,po
NAME                                                             READY   STATUS              RESTARTS         AGE
pod/download-uniref-data                                         1/1     Running             11 (3m34s ago)   116m
pod/esm2-worker-0                                                0/1     ContainerCreating    3 (30s ago)      2m4s
pod/esm2-worker-1                                                0/1     ContainerCreating   0                2m4s
pod/esm2-worker-2                                                0/1     ContainerCreating   0                2m4s
pod/esm2-worker-3                                                0/1     ContainerCreating   0                2m4s
```
To trace the training job logs, run the following command:
```bash
kubectl logs -f esm2-worker-0
--
esm2-worker-0:53:269 [0] NCCL INFO [Proxy Service] Device 0 CPU core 10
esm2-worker-0:53:270 [0] NCCL INFO [Proxy Service UDS] Device 0 CPU core 15
esm2-worker-0:53:267 [0] NCCL INFO threadThresholds 8/8/64 | 32/8/64 | 512 | 512
esm2-worker-0:53:267 [0] NCCL INFO 2 coll channels, 2 collnet channels, 0 nvls channels, 2 p2p channels, 2 p2p channels per peer
esm2-worker-0:53:267 [0] NCCL INFO TUNER/Plugin: Failed to find ncclTunerPlugin_v4 symbol.
esm2-worker-0:53:267 [0] NCCL INFO TUNER/Plugin: Failed to find ncclTunerPlugin_v3 symbol.
esm2-worker-0:53:267 [0] NCCL INFO TUNER/Plugin: Failed to find ncclTunerPlugin_v2 symbol, using internal tuner instead.
esm2-worker-0:53:267 [0] NCCL INFO ncclCommInitRankConfig comm 0x36477e40 rank 3 nranks 4 cudaDev 0 nvmlDev 0 busId 1e0 commId 0x15c1c76db987339e - Init COMPLETE
esm2-worker-0:53:267 [0] NCCL INFO Init timings - ncclCommInitRankConfig: rank 3 nranks 4 total 1.16 (kernels 0.18, alloc 0.04, bootstrap 0.93, allgathers 0.00, topo 0.00, graphs 0.00, connections 0.00, rest 0.00)
esm2-worker-0:53:272 [0] NCCL INFO [Proxy Progress] Device 0 CPU core 24
esm2-worker-0:53:271 [0] NCCL INFO Channel 00/0 : 2[0] -> 3[0] [receive] via NET/Socket/0
esm2-worker-0:53:271 [0] NCCL INFO Channel 01/0 : 2[0] -> 3[0] [receive] via NET/Socket/0
esm2-worker-0:53:271 [0] NCCL INFO Channel 00/0 : 3[0] -> 0[0] [send] via NET/Socket/0
esm2-worker-0:53:271 [0] NCCL INFO Channel 01/0 : 3[0] -> 0[0] [send] via NET/Socket/0
esm2-worker-0:53:271 [0] NCCL INFO Connected all rings, use ring PXN 0 GDR 0
[INFO|trainer.py:2128] 2025-04-24 20:44:49,943 >> ***** Running training *****
[INFO|trainer.py:2129] 2025-04-24 20:44:49,943 >>   Num examples = 100,000
[INFO|trainer.py:2130] 2025-04-24 20:44:49,943 >>   Num Epochs = 1
[INFO|trainer.py:2131] 2025-04-24 20:44:49,943 >>   Instantaneous batch size per device = 8
[INFO|trainer.py:2134] 2025-04-24 20:44:49,943 >>   Total train batch size (w. parallel, distributed & accumulation) = 32
[INFO|trainer.py:2135] 2025-04-24 20:44:49,943 >>   Gradient Accumulation steps = 1
[INFO|trainer.py:2136] 2025-04-24 20:44:49,943 >>   Total optimization steps = 3,125
[INFO|trainer.py:2137] 2025-04-24 20:44:49,943 >>   Number of trainable parameters = 7,840,794
```
Depending on the dataset size, it can take variable time to complete the traning jobs by ESM2 training pods.
After the ESM worker pods finish training jobs, they will be in `COMPLETE` state:

```bash
kubectl get pytorchjob,po
NAME                           STATE       AGE
pytorchjob.kubeflow.org/esm2   Succeeded   40m

NAME                                                             READY   STATUS      RESTARTS      AGE
pod/esm2-worker-0                                                0/1     Completed   0             40m
pod/esm2-worker-1                                                0/1     Completed   0             40m
pod/esm2-worker-2                                                0/1     Completed   0             40m
pod/esm2-worker-3                                                0/1     Completed   0             40m
```
Also, the following file with contents like shown below is expected at the OUTPUT shared directory:
```bash
/fsx-shared/esm/output/checkpoint-3125# cat config.json
{
  "_name_or_path": "facebook/esm2_t6_8M_UR50D",
  "architectures": [
    "EsmForMaskedLM"
  ],
  "attention_probs_dropout_prob": 0.0,
  "classifier_dropout": null,
  "emb_layer_norm_before": false,
  "esmfold_config": null,
  "hidden_act": "gelu",
  "hidden_dropout_prob": 0.0,
  "hidden_size": 320,
  "initializer_range": 0.02,
  "intermediate_size": 1280,
  "is_folding_model": false,
  "layer_norm_eps": 1e-05,
  "mask_token_id": 32,
  "max_position_embeddings": 1026,
  "model_type": "esm",
  "num_attention_heads": 20,
  "num_hidden_layers": 6,
  "pad_token_id": 1,
  "position_embedding_type": "rotary",
  "token_dropout": true,
  "torch_dtype": "float32",
  "transformers_version": "4.42.4",
  "use_cache": true,
  "vocab_list": null,
  "vocab_size": 33
}
```
## 7. Training Using FSDP Framework

Fully Sharded Data Parallel (FSDP) is an open-source distributed training technique provided by PyTorch. While Data Parallelism (DP) with no model sharding is typically the go-to method when a model fits within the memory of a single GPU, FSDP becomes an effective alternative for training models that exceed the memory capacity of a single GPU.

In order to prepare a FSDP based training job,  to generate specific training job manifest for K8s similar to how we did for DDP based training: 

```bash
cat train-fsdp-template.yaml.yaml | envsubst > train-fsdp.yaml
--
piVersion: v1
kind: Service
metadata:
  name: etcd
spec:
  ports:
    - name: etcd-client-port      port: 2379
      protocol: TCP
      targetPort: 2379
  selector:
    app: etcd

---
apiVersion: apps/v1kind: Deployment
metadata:
  labels:
    app: etcd
  name: etcd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: etcd
  template:
    metadata:
      labels:
        app: etcd
    spec:
      containers:
        - name: etcd
          command: ["/usr/local/bin/etcd"]
          args:
            - "--data-dir"
            - "/var/lib/etcd"
            - "--enable-v2"
            - "--listen-client-urls"
            - "http://0.0.0.0:2379"
            - "--advertise-client-urls"
            - "http://0.0.0.0:2379"
            - "--initial-cluster-state"
            - "new"
          image: quay.io/coreos/etcd:v3.5.19
          ports:
            - containerPort: 2379
              name: client
              protocol: TCP
            - containerPort: 2380
              name: server
              protocol: TCP
      restartPolicy: Always
---
apiVersion: "kubeflow.org/v1"
kind: PyTorchJob
metadata:
  name: esm2
spec:
  elasticPolicy:
    rdzvBackend: etcd
    rdzvHost: etcd
    rdzvPort: 2379
    minReplicas: 1
    maxReplicas: 64
    maxRestarts: 100
    metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 90
  pytorchReplicaSpecs:
    Worker:
      replicas: 4
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          tolerations:
            - key: nvidia.com/gpu
              operator: Exists
              effect: NoSchedule
          volumes:
          - name: fsx-pv-storage
            persistentVolumeClaim:
              claimName: fsx-claim
          containers:
            - name: pytorch
              image: 354918380621.dkr.ecr.us-east-1.amazonaws.com/esm:aws
              resources:
                requests:
                  nvidia.com/gpu: 1
                  vpc.amazonaws.com/efa: 1
                limits:
                  nvidia.com/gpu: 1
                  vpc.amazonaws.com/efa: 1
              env:
                - name: NCCL_DEBUG
                  value: "INFO"
              volumeMounts:
                - mountPath: /fsx-shared
                  name: fsx-pv-storage
              imagePullPolicy: Always
              command:
                - "accelerate launch"
                - --num_processes=1*4
                - --num_machines=4
                - --use_fsdp
                - --fsdp_sharding_strategy=FULL_SHARD
                - --fsdp_auto_wrap_policy=TRANSFORMER_BASED_WRAP
                - --fsdp_transformer_layer_cls_to_wrap=EsmLayer
                - --fsdp_backward_prefetch=BACKWARD_PRE
                - --fsdp_cpu_ram_efficient_loading=True
                - --fsdp_sync_module_states=True
                - --fsdp_use_orig_params=True
                - /workspace/train.py
                - --config_name=facebook/esm2_t6_8M_UR50D
                - --dataloader_num_workers=8
                - --bf16=True
                - --do_eval=True
                - --do_preprocess=False
                - --do_train=True
                - --gradient_accumulation_steps=1
                - --logging_steps=16
                - --num_train_epochs=1
                - --output_dir=/fsx-shared/esm
                - --per_device_train_batch_size=8
                - --max_train_samples=100000
                - --tokenizer_name=facebook/esm2_t6_8M_UR50D
                - --dataset_dir=/fsx-shared/esm/processed/arrow
                - --torch_compile=True
                - --pad_to_max_length=True
                - --max_seq_length=512
---
```
To initiate FSDP based PyTurch training job, run the command: 
```bash
kubectl apply -f train-fsdp.yaml
---
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/esm2 created
```
To monitor how ESM worker pods process model training you can run the following command:

```bash
kubectl logs -f esm2-worker-0
[WARNING  | accelerate.commands.launch]: The following values were not passed to `accelerate launch` and had defaults used instead:
        `--mixed_precision` was set to a value of `'no'`
        `--dynamo_backend` was set to a value of `'no'`
To avoid this warning pass in values for each of the problematic parameters or run `accelerate config`.
INFO 2025-05-06 04:09:27,315 Etcd machines: ['http://0.0.0.0:2379']
...
INFO 2025-05-06 04:09:27,391 Attempting to join next rendezvous
INFO 2025-05-06 04:09:27,463 New rendezvous state created: {'status': 'joinable', 'version': '1', 'participants': []}
INFO 2025-05-06 04:09:27,565 Joined rendezvous version 1 as rank 0. Full state: {'status': 'joinable', 'version': '1', 'participants': [0]}
INFO 2025-05-06 04:09:27,566 Waiting for remaining peers.
...
```
