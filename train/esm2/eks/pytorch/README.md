## 0. Available ESM2 models on HuggingFace

1. [facebook/esm2_t6_8M_UR50D](https://huggingface.co/facebook/esm2_t6_8M_UR50D)
2. [facebook/esm2_t12_35M_UR50D](https://huggingface.co/facebook/esm2_t12_35M_UR50D)
3. [facebook/esm2_t30_150M_UR50D](https://huggingface.co/facebook/esm2_t30_150M_UR50D)
4. [facebook/esm2_t33_650M_UR50D](https://huggingface.co/facebook/esm2_t33_650M_UR50D)
5. [facebook/esm2_t36_3B_UR50D](https://huggingface.co/facebook/esm2_t36_3B_UR50D)
6. [facebook/esm2_t48_15B_UR50D](https://huggingface.co/facebook/esm2_t48_15B_UR50D)


## 1. Setup environment variables

SSH into the head or login node of your cluster or connect to VM that has access to its Kubernetes API and run:

```
# Path to save training data and checkpoints
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

Next we need to download the Uniref50 training data. You can do so by running the following K8s job:

```bash
cat download-data-template.yaml | envsubst > download-data-real.yaml
```
Then apply it via CLI call:
```bash
kubectl apply -f download-data-real.yaml
```

Output:
```
job/download-uniref-data created
```

It would download the data and partitions the data in 50 .csv files in the folder specified by the `TARGET_PATH` environment variable. 
The whole process should take less than 30 mins. 
You can monitor the process by tailing the pod created by the Job:

``` bash
kubectl logs -f download-uniref-data-g245r
```

Output:
```
05/21/2025 21:35:03 - INFO - Parsing arguments
05/21/2025 21:35:03 - INFO - Downloading FASTA
05/21/2025 21:35:03 - INFO - Downloading https://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref50/uniref50.fasta.gz to /workspace/tmphdt41nh1/fasta
https://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref50/uniref50.fasta.gz: 100%|██████████| 13.6G/13.6G [01:05<00:00, 222MB/s]
05/21/2025 21:36:08 - INFO - Generating csv files
Reading FASTA file
498366it [00:10, 68862.07it/s]05/21/2025 21:36:19 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x000.csv
992530it [00:32, 90643.92it/s]05/21/2025 21:36:41 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x001.csv
1490619it [00:47, 103665.90it/s]05/21/2025 21:36:55 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x002.csv
1992703it [00:59, 114299.16it/s]05/21/2025 21:37:08 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x003.csv
2491566it [01:10, 124266.36it/s]05/21/2025 21:37:18 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x004.csv
2987781it [01:19, 132450.56it/s]05/21/2025 21:37:28 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x005.csv
...
8957193it [08:17, 686030.19it/s]04/18/2025 22:13:06 - INFO - Writing 500000 records to /fsx-shared/esm/csv/x137.csv
69290910it [08:18, 139067.03it/s]
04/18/2025 22:13:07 - INFO - Writing 290910 records to /fsx-shared/esm/csv/x138.csv
04/18/2025 22:13:09 - INFO - Save complete
```
If we check status of launched job and corresponding pod, they should be `Complete` and `Completed` respectively:

```bash
kc get job,po
```
Output:

```
NAME                             STATUS     COMPLETIONS   DURATION   AGE
job.batch/download-uniref-data   Complete   1/1           14m        24m

NAME                                                             READY   STATUS      RESTARTS      AGE
pod/download-uniref-data-g245r                                   0/1     Completed   0             24m
pod/fsx-share-test                                               1/1     Running     0             11m
pod/hyperpod-dependencies-aws-efa-k8s-device-plugin-dlxs8        1/1     Running     0             27h
```

We can also valildate contents of the shared data directory `fsx-shared/esm` using the provided `view-fsx.yaml` deployment descriptor that creates a pod with that directory mounted:

```bash
kubectl apply -f view-fsx.yaml
```
Output:
```
pod/fsx-share-test created
```

Using that pod, we can get "inside" and review contents of the shared data folder:
```bash
kubectl exec -it fsx-share-test -- ls -ltr /fsx-shared/esm/csv
```
Output:
```
total 20593930
-rw-r--r-- 1 root root 1338965519 May 21 21:36 x000.csv
-rw-r--r-- 1 root root  739136803 May 21 21:36 x001.csv
-rw-r--r-- 1 root root  608770034 May 21 21:37 x002.csv
-rw-r--r-- 1 root root  537187950 May 21 21:37 x003.csv
-rw-r--r-- 1 root root  487469687 May 21 21:37 x004.csv
-rw-r--r-- 1 root root  449800266 May 21 21:37 x005.csv
-rw-r--r-- 1 root root  419801146 May 21 21:37 x006.csv
...
-rw-r--r-- 1 root root   35932545 May 21 21:44 x135.csv
-rw-r--r-- 1 root root   32936597 May 21 21:44 x136.csv
-rw-r--r-- 1 root root   29808230 May 21 21:44 x137.csv
-rw-r--r-- 1 root root   23821111 May 21 21:44 x138.csv
```


## 5. Convert CSVs to HuggingFace Dataset and Tokenize

Next we need to tokenize the dataset in order to provide training data in the specified format. This will split the data in training, test and validation folders, tokenize them and save the arrow files in `processed` folder.

```bash
cat preprocess-template.yaml | envsubst > preprocess-data.yaml
cat preprocess-data.yaml
------
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
```
Output:
```
pod/preprocess-data created
```
You can check the progress of data pre-processing by tailing that pod log:

```bash
kc logs -f preprocess-data
```
Output:
```
05/21/2025 22:02:00 - INFO - Parsing arguments
05/21/2025 22:02:00 - INFO - Loading csv files from /fsx-shared/esm/csv
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 11893.11files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 41688.28files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 12151.53files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 19210.55files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 11163.31files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 59028.52files/s]
Downloading data: 100%|██████████| 18/18 [00:00<00:00, 14725.47files/s]
Generating train split: 69488478 examples [00:44, 1576533.60 examples/s]
05/21/2025 22:02:49 - INFO - DatasetDict({
    train: Dataset({
        features: ['text'],
        num_rows: 69488478
    })
})
05/21/2025 22:02:49 - INFO - Splitting dataset
Flattening the indices: 100%|██████████| 10000000/10000000 [01:20<00:00, 124318.23 examples/s]
Flattening the indices: 100%|██████████| 50000/50000 [00:00<00:00, 117854.94 examples/s]
Flattening the indices: 100%|██████████| 50000/50000 [00:00<00:00, 116411.89 examples/s]
05/21/2025 22:04:16 - INFO - Saving splits to csv
...
05/21/2025 22:45:41 - INFO - Processing line by line
Running tokenizer on dataset line_by_line (num_proc=8): 100%|██████████| 10000000/10000000 [12:36<00:00, 13211.30 examples/s]
Running tokenizer on dataset line_by_line (num_proc=8): 100%|██████████| 50000/50000 [00:05<00:00, 9848.93 examples/s]
Running tokenizer on dataset line_by_line (num_proc=8): 100%|██████████| 50000/50000 [00:05<00:00, 9857.74 examples/s]
Saving the dataset (62/62 shards): 100%|██████████| 10000000/10000000 [00:51<00:00, 193657.14 examples/s]
Saving the dataset (1/1 shards): 100%|██████████| 50000/50000 [00:00<00:00, 190996.75 examples/s]
Saving the dataset (1/1 shards): 100%|██████████| 50000/50000 [00:00<00:00, 198004.43 examples/s]
```
To review the status of data tokenization, we can use the same `fsx-share-test` pod used in previous step and run the following command:

```bash
kubectl exec -it fsx-share-test  -- ls -ltr /fsx-shared/esm/processed/arrow/train
```
Output:
```
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
-rw-r--r-- 1 root root 497485216 May 21 22:19 data-00060-of-00062.arrow
-rw-r--r-- 1 root root      3846 May 21 22:19 state.json
-rw-r--r-- 1 root root     15333 May 21 22:19 dataset_info.json
-rw-r--r-- 1 root root 497485216 May 21 22:19 data-00061-of-00062.arrow
```

## 6. Training Using DDP Framework

Now we are ready to submit distributed training jobs to pretrain ESM2 models. We provide the `train-ddp-template.yaml` template to run training on  HyperPod EKS cluster compute nodes with certain number of GPUs, per node specification. Make sure data paths and model configuration is correct if you are running on custom data set.

To kick off DDP framework based distributed training execute, we first need to generate specific training job manifest for K8s:

```bash
cat train-ddp-template.yaml | envsubst > train-ddp.yaml
cat train-ddp.yaml
-----
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
```
Output:
```
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/esm2 created
```
To validate status of the ESM-2 training job containers, run the following command (assuming they run in the `default` namespace):
```bash
kubectl get job,po
```
Output:
```
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
```
Output:
```
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
```
Output:
```
NAME                           STATE       AGE
pytorchjob.kubeflow.org/esm2   Succeeded   40m

NAME                                                             READY   STATUS      RESTARTS      AGE
pod/esm2-worker-0                                                0/1     Completed   0             40m
pod/esm2-worker-1                                                0/1     Completed   0             40m
pod/esm2-worker-2                                                0/1     Completed   0             40m
pod/esm2-worker-3                                                0/1     Completed   0             40m
```
Finally, to verify that model training has been indeed complete, you can display that following file with contents like shown below is expected at the $OUTPUT_DIR shared directory using the "helper" pod `fsx-share-test`:

```bash
kubectl exec -it fsx-share-test -- cat /fsx-shared/esm/output/train_results.json
```
Output:
```
{
    "epoch": 1.0,
    "total_flos": 2304587980079104.0,
    "train_loss": 2.638172448425293,
    "train_runtime": 278.2115,
    "train_samples": 100000,
    "train_samples_per_second": 359.439,
    "train_steps_per_second": 11.232
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
                - accelerate
                - launch
                - --num_processes=2 # Total GPUs
                - --num_machines=2 # Num Nodes
                - --machine_rank=$(POD_RANK)
                - --rdzv_backend=etcd
                - --main_process_port=2379
                - --main_process_ip=etcd
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
                - --dataloader_num_workers=2
                - --bf16=True
                - --do_eval=True
                - --do_preprocess=False
                - --do_train=True
                - --gradient_accumulation_steps=11
                - --logging_steps=16
                - --num_train_epochs=1
                - --output_dir=/fsx-shared/fsdp-ouput
                - --overwrite_output_dir
                - --per_device_train_batch_size=4
                - --max_train_samples=100000
                - --tokenizer_name=facebook/esm2_t6_8M_UR50D
                - --dataset_dir=/fsx-shared/esm/processed/arrow
                - --torch_compile=False
                - --pad_to_max_length=True
                - --max_seq_length=512
---
```
To initiate FSDP based PyTurch training job, run the command: 
```bash
kubectl apply -f train-fsdp.yaml
```
Output:
```
---
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/esm2 created
```
To monitor how ESM worker pods process model training you can run the following command against one of the worker nodes

```bash
kubectl logs -f esm2-worker-0
```
Output:
```
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
[INFO|tokenization_utils_base.py:2583] 2025-05-06 20:51:15,555 >> Special tokens file saved in /fsx-shared/fsdp-ouput/special_tokens_map.json
***** train metrics *****
  epoch                    =     0.9997
  total_flos               =  1072814GF
  train_loss               =     2.6578
  train_runtime            = 0:08:52.30
  train_samples            =     100000
  train_samples_per_second =    187.862
  train_steps_per_second   =      2.134
[INFO     | __main__           ]: *** Evaluate ***
[INFO|trainer.py:805] 2025-05-06 20:51:15,572 >> The following columns in the evaluation set don't have a corresponding argument in `FullyShardedDataParallel.forward` and have been ignored: special_tokens_mask. If special_tokens_mask are not expected by `FullyShardedDataParallel.forward`,  you can safely ignore this message.
[INFO|trainer.py:3788] 2025-05-06 20:51:15,574 >>
***** Running Evaluation *****
[INFO|trainer.py:3790] 2025-05-06 20:51:15,574 >>   Num examples = 50000
[INFO|trainer.py:3793] 2025-05-06 20:51:15,574 >>   Batch size = 8
100%|██████████| 3125/3125 [01:34<00:00, 33.23it/s]
[INFO     | __main__           ]: Metrics are {'eval_loss': 2.6308915615081787, 'eval_accuracy': 0.20261175918653207, 'eval_runtime': 94.2151, 'eval_samples_per_second': 530.7, 'eval_steps_per_second': 33.169, 'epoch': 0.99968}
[INFO     | __main__           ]: Calculating perplexity
[INFO     | __main__           ]: Perplexity: 13.886144736991477
***** eval metrics *****
  epoch                   =     0.9997
  eval_accuracy           =     0.2026
  eval_loss               =     2.6309
  eval_runtime            = 0:01:34.21
  eval_samples            =      50000
  eval_samples_per_second =      530.7
  eval_steps_per_second   =     33.169
  perplexity              =    13.8861
[INFO|modelcard.py:449] 2025-05-06 20:52:49,880 >> Dropping the following result as it does not have all the necessary fields:
{'task': {'name': 'Masked Language Modeling', 'type': 'fill-mask'}, 'metrics': [{'name': 'Accuracy', 'type': 'accuracy', 'value': 0.20261175918653207}]}
[rank0]:[W506 20:52:51.546147488 ProcessGroupNCCL.cpp:1487] Warning: WARNING: destroy_process_group() was not called before program exit, which can leak resources. For more info, please see https://pytorch.org/docs/stable/distributed.html#shutdown (function operator())
esm2-worker-0:161:315 [0] NCCL INFO misc/socket.cc:64 -> 3
esm2-worker-0:161:315 [0] NCCL INFO misc/socket.cc:80 -> 3
esm2-worker-0:161:315 [0] NCCL INFO misc/socket.cc:828 -> 3
esm2-worker-0:161:286 [0] NCCL INFO misc/socket.cc:880 -> 3
esm2-worker-0:161:315 [0] NCCL INFO comm 0x2e177b70 rank 0 nranks 2 cudaDev 0 busId 1e0 - Abort COMPLETE
```
To confirm that PyTorch training job completed successfully along with ESM worker pods, you can run the following command:
```bash
kubectl get pytorchjob,po,svc
```
Output:
```
NAME                           STATE       AGE
pytorchjob.kubeflow.org/esm2   Succeeded   122m

NAME                                                             READY   STATUS      RESTARTS      AGE
pod/esm2-worker-0                                                0/1     Completed   0             122m
pod/esm2-worker-1                                                0/1     Completed   0             122m
pod/etcd-6cd66c884c-t4xm7                                        1/1     Running     0             122m
pod/fsx-share-test                                               1/1     Running     0             108m
....
```
Finally, to verify that model training has been indeed complete, you can display that following file with contents like shown below is expected at the $OUTPUT_DIR shared directory using the "helper" pod `fsx-share-test`:

```bash
kubectl exec -it fsx-share-test -- cat /fsx-shared/fsdp-output/train_results.json
```
Output:
```console
{
    "epoch": 0.99968,
    "total_flos": 1151925283717120.0,
    "train_loss": 2.657833001982998,
    "train_runtime": 532.3045,
    "train_samples": 100000,
    "train_samples_per_second": 187.862,
    "train_steps_per_second": 2.134
}
```