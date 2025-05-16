# Train Evolutionary Scale Models (ESM-2) with BioNemo Framework

[NVIDIA BioNeMo](https://docs.nvidia.com/bionemo-framework/latest/) is a domain-specific machine learning framework for training and using foundation models for biology. This includes models for analyzing proteins, small molecules, and other biological molecules. To see the latest models available in BioNeMo 2.5 see [here](https://docs.nvidia.com/bionemo-framework/latest/models/).

This guidance provides step by step instructions to pretrain [ESM2](https://docs.nvidia.com/bionemo-framework/latest/models/ESM-2/) models with NVIDIA BioNeMo on Sagemaker HyPerPod slurm clusters.

## 0. Prerequisites

Have a EKS based Sagemaker HyperPod cluster with Nvidia GPUs. You can verify available number of GPUs and number of EFA devices like below:

```bash
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,INSTANCETYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa"

NAME                           INSTANCETYPE     GPU   EFA
hyperpod-i-048cd15160ee28917   ml.p5.48xlarge   8     32
hyperpod-i-09539ee1dd9971647   ml.p5.48xlarge   8     32
```

## 1. Setup environment variables

Set the following values in the OS environment where you will be running the BioNemo training:  

```
# Path to save training data and checkpoints

export AWS_REGION=us-west-1
export DOCKER_IMAGE_NAME=bionemo
export TAG=aws
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/

export GPU_PER_NODE=8
export EFA_PER_NODE=32

export NUM_NODES=2
export OUTPUT_DIR=/fsx-shared/bionemo
```

Or just run the following command using the `env.conf` file:
```
source .env.conf
```

## 2. Pull this github repo

```bash
git clone https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework.git

cd guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework/source/hyperpod_eks
chmod 777 *.sh
```
## 3. Build and push Docker Image

We provide an AWS optimized Docker image that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly:

```bash
./build.sh
```
Once built you can push the Docker image to ECR as follows:

```bash
./push.sh
```
You can verify that an image with tag ending with `bionemo:aws` is indeed present in the ECR

## 4. Download Training data

BioNeMo 2.5 container provides a CLI `download_bionemo_data` to download test or full UniProt dataset from NVIDIA Catalog which we can run as below. To that end we provide a `get-data-template.yaml`. First substitute the environment variables to generate `get-data.yaml` like below:

```bash
cat get-data-template.yaml | envsubst > get-data.yaml
cat get-data.yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: download-bionemo-data
spec:
  containers:
  - name: download-bionemo-data
    image: 3549183XXXXX.dkr.ecr.us-east-1.amazonaws.com/bionemo:aws
    command: ["/bin/bash"]
    args: ["-c", "download_bionemo_data esm2/testdata_esm2_pretrain:2.0"]
    volumeMounts:
    - name: bionemo-cache-volume
      mountPath: /root/.cache/bionemo
  volumes:
  - name: bionemo-cache-volume
    persistentVolumeClaim:
      claimName: fsx-claim
```

The you can start the data downloading job as below. The pod will take roughly 6 minutes to start as it is a about 35GB image.

```bash
kubectl apply -f get-data.yaml
pod/download-bionemo-data created
```

You can monitor progress of data download by running a command like:
```bash
kubectl logs -f download-bionemo-data
---
/root/.cache/bionemo/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar
```
To verify that the data is available in the shared filesystem, we need a dummy pod with that shared filesystem mounted. For that purpose we provide       `view-fsx.yaml` which creates a pod called `fsx-share-test`. To view the contents of the file system we can exec in the pod as below:

```bash
# Create the pod
kubectl apply -f view-fsx.yaml
# Exec in the pod and list the directory contents
kubectl exec fsx-share-test -- ls -al /fsx-shared
total 71990
....
-rw-r--r--  1 root root 73307674 May  6 23:38 006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz
drwxr-xr-x  3 root root    25600 May  6 23:38 006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar
```

Once data download is completed, export the `DATA_DIR` as an environment variable as below using the `*.untar` folder name prefixing that with shared data folder path:

```bash
export DATA_DIR=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar
```

## 5. Pretrain BioNemo ESM2 models

Now we are ready to submit distributed training jobs to pretrain `ESM2` models. We provide the `esm2-pretrain-template.yaml` script to run training on various SageMaker HyperPode compute nodes with various number of GPUs. Make sure data paths and model configuration parameters is correct if you are running on custom data. 

To kick off distributed training, first we need to generate customized deployment descriptor for BioNemo training job:

```bash
cat esm2-pretrain-template.yaml | envsubst > esm2-pretrain.yaml
```
Validate the resulting training job deployment descriptor:
```bash
cat esm2-pretrain.yaml
---
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
  name: bionemo-esm2
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
      replicas: 2
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
          - name: shmem
            hostPath:
              path: /dev/shm
          containers:
            - name: pytorch
              image: 3549183XXXXX.dkr.ecr.us-east-1.amazonaws.com/bionemo:aws
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
                #- name: LOGLEVEL
                #  value: "DEBUG"
                #- name: FI_PROVIDER
                #  value: efa
                #- name: FI_EFA_USE_DEVICE_RDMA
                #  value: "1"
                #- name: FI_EFA_FORK_SAFE
                #  value: "1"
                #- name: FI_LOG_LEVEL
                #  value: "1"
                #- name: FI_EFA_ENABLE_SHM_TRANSFER
                #  value: "1"
                #- name: TORCH_DISTRIBUTED_DEBUG
                #  value: "DETAIL"
                #- name: TORCH_NCCL_ASYNC_ERROR_HANDLING
                #  value: "1"
                #- name: PYTORCH_CUDA_ALLOC_CONF
                #  value: "expandable_segments:True"
                #- name: NCCL_SOCKET_IFNAME
                #  value: "^lo"
              volumeMounts:
                - mountPath: /fsx-shared
                  name: fsx-pv-storage
                - mountPath: /dev/shm
                  name: shmem
              imagePullPolicy: Always
              command:
                - torchrun
                - --nproc_per_node=1
                - --nnodes=2
                - /workspace/bionemo2/sub-packages/bionemo-esm2/src/bionemo/esm2/scripts/train_esm2.py
                - --train-cluster-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/train_clusters_sanity.parquet
                - --train-database-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/train_sanity.db
                - --valid-cluster-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/valid_clusters.parquet
                - --valid-database-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/validation.db
                - --precision=bf16-mixed
                - --num-gpus=1
                - --num-nodes=2
                - --num-steps=100
                - --val-check-interval=25
                - --max-seq-length=1024
                - --limit-val-batches=2
                - --micro-batch-size=2
                - --num-layers=33
                - --hidden-size=1280
                - --num-attention-head=20
                - --ffn-hidden-size=5120
                - --tensor-model-parallel-size=1
                - --create-tensorboard-logger
                - --result-dir=/fsx-shared/bionemo
```

To initiate a training job, apply generated deployment descriptor to EKS API:
```bash
kubectl apply -f esm2-pretrain.yaml
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/bionemo-esm2 created
```
To monitor BioNemo training job, you can check status of PyTorchJob, Deployment and Pods related to them:
```bash
kubectl get pytorchjob,deploy,po,svc
NAME                                   STATE     AGE
pytorchjob.kubeflow.org/bionemo-esm2   Running   2m37s

NAME                                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/etcd                                        1/1     1            1           2m37s
deployment.apps/hyperpod-dependencies-hyperpod-helm-chart   1/1     1            1           118d
deployment.apps/hyperpod-dependencies-mpi-operator          1/1     1            1           118d

NAME                                                             READY   STATUS              RESTARTS      AGE
pod/bionemo-esm2-worker-0                                        1/1     Running             0             2m37s
pod/bionemo-esm2-worker-1                                        0/1     ContainerCreating   0             2m37s
..
```
To tail ESM model training running pod logs, you can run the following command:
```bash
kubectl logs -f  bionemo-esm2-worker-0
INFO 2025-05-15 23:40:46,089 Etcd machines: ['http://0.0.0.0:2379']
....
INFO 2025-05-15 23:40:46,099 Attempting to join next rendezvous
INFO 2025-05-15 23:40:46,107 New rendezvous state created: {'status': 'joinable', 'version': '1', 'participants': []}
INFO 2025-05-15 23:40:46,207 Joined rendezvous version 1 as rank 1. Full state: {'status': 'frozen', 'version': '1', 'participants': [0, 1], 'keep_alives': []}
INFO 2025-05-15 23:40:46,207 Waiting for remaining peers.
INFO 2025-05-15 23:40:46,207 All peers arrived. Confirming membership.
INFO 2025-05-15 23:40:46,230 Waiting for confirmations from all peers.
INFO 2025-05-15 23:40:46,272 Rendezvous version 1 is complete. Final state: {'status': 'final', 'version': '1', 'participants': [0, 1], 'keep_alives': ['/torchelastic/p2p/run_none/rdzv/v_1/rank_1', '/torchelastic/p2p/run_none/rdzv/v_1/rank_0'], 'num_workers_waiting': 0}
INFO 2025-05-15 23:40:46,272 Creating EtcdStore as the c10d::Store implementation

Initializing distributed: GLOBAL_RANK: 1, MEMBER: 2/2
bionemo-esm2-worker-0:53:53 [0] NCCL INFO cudaDriverVersion 12040
bionemo-esm2-worker-0:53:53 [0] NCCL INFO NCCL_SOCKET_IFNAME set by environment to ^docker,lo,veth
bionemo-esm2-worker-0:53:53 [0] NCCL INFO Bootstrap: Using eth0:10.1.75.163<0>
bionemo-esm2-worker-0:53:53 [0] NCCL INFO NCCL version 2.25.1+cuda12.8
bionemo-esm2-worker-0:53:53 [0] NCCL INFO Comm config Blocking set to 1
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/Plugin: Failed to find ncclNetPlugin_v9 symbol.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/Plugin: Loaded net plugin Libfabric (v8)
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/Plugin: Failed to find ncclCollNetPlugin_v9 symbol.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/Plugin: Failed to find ncclCollNetPlugin symbol (>= v5). ncclCollNetPlugin symbols v4 and lower are not supported.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Initializing aws-ofi-nccl 1.13.2-aws
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Using Libfabric version 1.22
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Using CUDA driver version 12040 with runtime 12080
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Configuring AWS-specific options
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Setting provider_filter to efa
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Setting FI_EFA_FORK_SAFE environment variable to 1
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Setting NCCL_NVLSTREE_MAX_CHUNKSIZE to 512KiB
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Setting NCCL_NVLS_CHUNKSIZE to 512KiB
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Internode latency set at 75.0 us
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Selected Provider is efa (found 1 nics)
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI NIC group 0 device #0 0000:00:1d.0
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Selected Provider is efa (found 1 nics)
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Using transport protocol SENDRECV
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Creating one domain per process
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Could not disable CUDA API usage for HMEM, disabling GDR
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Setting FI_OPT_EFA_SENDRECV_IN_ORDER_ALIGNED_128_BYTES not supported.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Setting NCCL_PROTO to "simple"
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Support for global registrations: false
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NET/OFI Support for DMA-BUF registrations: false
bionemo-esm2-worker-0:53:323 [0] NCCL INFO PROFILER/Plugin: Could not find: libnccl-profiler.so.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO Using network Libfabric
bionemo-esm2-worker-0:53:323 [0] NCCL INFO DMA-BUF is available on GPU device 0
bionemo-esm2-worker-0:53:323 [0] NCCL INFO ncclCommInitRankConfig comm 0x276ecff0 rank 1 nranks 2 cudaDev 0 nvmlDev 0 busId 1e0 commId 0xbbcf61767c6f7be7 - Init START
bionemo-esm2-worker-0:53:323 [0] NCCL INFO RAS client listening socket at ::1<28028>
bionemo-esm2-worker-0:53:323 [0] NCCL INFO Bootstrap timings total 0.002316 (create 0.000031, send 0.000485, recv 0.000787, ring 0.000243, delay 0.000000)
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NCCL_NVLS_ENABLE set by environment to 0.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO comm 0x276ecff0 rank 1 nRanks 2 nNodes 2 localRanks 1 localRank 0 MNNVL 0
bionemo-esm2-worker-0:53:323 [0] NCCL INFO Trees [0] -1/-1/-1->1->0 [1] 0/-1/-1->1->-1
bionemo-esm2-worker-0:53:323 [0] NCCL INFO P2P Chunksize set to 131072
bionemo-esm2-worker-0:53:325 [0] NCCL INFO [Proxy Service] Device 0 CPU core 10
bionemo-esm2-worker-0:53:326 [0] NCCL INFO [Proxy Service UDS] Device 0 CPU core 6
bionemo-esm2-worker-0:53:323 [0] NCCL INFO NCCL_PROTO set by environment to simple
bionemo-esm2-worker-0:53:323 [0] NCCL INFO threadThresholds 8/8/64 | 16/8/64 | 512 | 512
bionemo-esm2-worker-0:53:323 [0] NCCL INFO 2 coll channels, 2 collnet channels, 0 nvls channels, 2 p2p channels, 2 p2p channels per peer
bionemo-esm2-worker-0:53:323 [0] NCCL INFO TUNER/Plugin: Failed to find ncclTunerPlugin_v4 symbol.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO TUNER/Plugin: Failed to find ncclTunerPlugin_v3 symbol.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO TUNER/Plugin: Failed to find ncclTunerPlugin_v2 symbol, using internal tuner instead.
bionemo-esm2-worker-0:53:323 [0] NCCL INFO ncclCommInitRankConfig comm 0x276ecff0 rank 1 nranks 2 cudaDev 0 nvmlDev 0 busId 1e0 commId 0xbbcf61767c6f7be7 - Init COMPLETE
bionemo-esm2-worker-0:53:323 [0] NCCL INFO Init timings - ncclCommInitRankConfig: rank 1 nranks 2 total 0.19 (kernels 0.12, alloc 0.06, bootstrap 0.00, allgathers 0.00, topo 0.00, graphs 0.00, connections 0.00, rest 0.00)
bionemo-esm2-worker-0:53:328 [0] NCCL INFO [Proxy Progress] Device 0 CPU core 3
bionemo-esm2-worker-0:53:327 [0] NCCL INFO Channel 00/0 : 0[0] -> 1[0] [receive] via NET/Libfabric/0
bionemo-esm2-worker-0:53:327 [0] NCCL INFO Channel 01/0 : 0[0] -> 1[0] [receive] via NET/Libfabric/0
bionemo-esm2-worker-0:53:327 [0] NCCL INFO Channel 00/0 : 1[0] -> 0[0] [send] via NET/Libfabric/0
bionemo-esm2-worker-0:53:327 [0] NCCL INFO Channel 01/0 : 1[0] -> 0[0] [send] via NET/Libfabric/0
bionemo-esm2-worker-0:53:327 [0] NCCL INFO Connected all rings, use ring PXN 0 GDR 0
LOCAL_RANK: 0 - CUDA_VISIBLE_DEVICES: [0]
bionemo-esm2-worker-0:53:53 [0] NCCL INFO Comm config Blocking set to 1
bionemo-esm2-worker-0:53:401 [0] NCCL INFO Using network Libfabric
bionemo-esm2-worker-0:53:401 [0] NCCL INFO DMA-BUF is available on GPU device 0
bionemo-esm2-worker-0:53:401 [0] NCCL INFO ncclCommInitRankConfig comm 0x3133b010 rank 1 nranks 2 cudaDev 0 nvmlDev 0 busId 1e0 commId 0xcfe7f3dc6fd0384b - Init START
bionemo-esm2-worker-0:53:401 [0] NCCL INFO Bootstrap timings total 0.002248 (create 0.000032, send 0.000431, recv 0.000773, ring 0.000521, delay 0.000000)
bionemo-esm2-worker-0:53:401 [0] NCCL INFO comm 0x3133b010 rank 1 nRanks 2 nNodes 2 localRanks 1 localRank 0 MNNVL 0
bionemo-esm2-worker-0:53:401 [0] NCCL INFO Trees [0] -1/-1/-1->1->0 [1] 0/-1/-1->1->-1
bionemo-esm2-worker-0:53:401 [0] NCCL INFO P2P Chunksize set to 131072
bionemo-esm2-worker-0:53:402 [0] NCCL INFO [Proxy Service] Device 0 CPU core 27
bionemo-esm2-worker-0:53:403 [0] NCCL INFO [Proxy Service UDS] Device 0 CPU core 6
bionemo-esm2-worker-0:53:401 [0] NCCL INFO NCCL_PROTO set by environment to simple
bionemo-esm2-worker-0:53:401 [0] NCCL INFO threadThresholds 8/8/64 | 16/8/64 | 512 | 512
bionemo-esm2-worker-0:53:401 [0] NCCL INFO 2 coll channels, 2 collnet channels, 0 nvls channels, 2 p2p channels, 2 p2p channels per peer
bionemo-esm2-worker-0:53:401 [0] NCCL INFO ncclCommInitRankConfig comm 0x3133b010 rank 1 nranks 2 cudaDev 0 nvmlDev 0 busId 1e0 commId 0xcfe7f3dc6fd0384b - Init COMPLETE
bionemo-esm2-worker-0:53:401 [0] NCCL INFO Init timings - ncclCommInitRankConfig: rank 1 nranks 2 total 0.01 (kernels 0.00, alloc 0.00, bootstrap 0.00, allgathers 0.00, topo 0.00, graphs 0.00, connections 0.00, rest 0.00)
bionemo-esm2-worker-0:53:405 [0] NCCL INFO [Proxy Progress] Device 0 CPU core 24
bionemo-esm2-worker-0:53:404 [0] NCCL INFO Channel 00/0 : 0[0] -> 1[0] [receive] via NET/Libfabric/0
bionemo-esm2-worker-0:53:404 [0] NCCL INFO Channel 01/0 : 0[0] -> 1[0] [receive] via NET/Libfabric/0
bionemo-esm2-worker-0:53:404 [0] NCCL INFO Channel 00/0 : 1[0] -> 0[0] [send] via NET/Libfabric/0
bionemo-esm2-worker-0:53:404 [0] NCCL INFO Channel 01/0 : 1[0] -> 0[0] [send] via NET/Libfabric/0
bionemo-esm2-worker-0:53:404 [0] NCCL INFO Connected all rings, use ring PXN 0 GDR 0
bionemo-esm2-worker-0:53:53 [0] NCCL INFO Comm config Blocking set to 1
bionemo-esm2-worker-0:53:710 [0] NCCL INFO Using network Libfabric
bionemo-esm2-worker-0:53:710 [0] NCCL INFO DMA-BUF is available on GPU device 0
bionemo-esm2-worker-0:53:710 [0] NCCL INFO ncclCommInitRankConfig comm 0x4d447740 rank 0 nranks 1 cudaDev 0 nvmlDev 0 busId 1e0 commId 0x776afb8cbd2c57bc - Init START
bionemo-esm2-worker-0:53:710 [0] NCCL INFO Bootstrap timings total 0.000367 (create 0.000033, send 0.000094, recv 0.000102, ring 0.000001, delay 0.000000)
....
[NeMo I 2025-05-15 23:42:46 nemo_logging:393] Async finalization time took 0.001 s
Validation: iteration 1/2
Validation: iteration 2/2
[NeMo I 2025-05-15 23:42:47 nemo_logging:393] Async finalization time took 0.001 s
[INFO     | pytorch_lightning.utilities.rank_zero]: `Trainer.fit` stopped: `max_steps=100` reached.
[NeMo I 2025-05-15 23:42:47 nemo_logging:393] Pending async checkpoint saves. Finalizing them synchronously now
[NeMo I 2025-05-15 23:42:54 nemo_logging:393] Successfully saved checkpoint from iteration      49 to /fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=3.11-step=49-consumed_samples=200.0.ckpt
[NeMo I 2025-05-15 23:42:54 nemo_logging:393] Async checkpoint save for step 50 (/fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=3.11-step=49-consumed_samples=200.0.ckpt) finalized successfully.
[NeMo I 2025-05-15 23:43:04 nemo_logging:393] Successfully saved checkpoint from iteration      49 to /fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=3.11-step=49-consumed_samples=200.0-last.ckpt
[NeMo I 2025-05-15 23:43:04 nemo_logging:393] Async checkpoint save for step 50 (/fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=3.11-step=49-consumed_samples=200.0-last.ckpt) finalized successfully.
[NeMo I 2025-05-15 23:43:22 nemo_logging:393] Successfully saved checkpoint from iteration      74 to /fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=3.04-step=74-consumed_samples=300.0.ckpt
[NeMo I 2025-05-15 23:43:22 nemo_logging:393] Async checkpoint save for step 75 (/fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=3.04-step=74-consumed_samples=300.0.ckpt) finalized successfully.
[NeMo I 2025-05-15 23:43:22 nemo_logging:393] Successfully saved checkpoint from iteration      74 to /fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=3.04-step=74-consumed_samples=300.0-last.ckpt
[NeMo I 2025-05-15 23:43:22 nemo_logging:393] Async checkpoint save for step 75 (/fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=3.04-step=74-consumed_samples=300.0-last.ckpt) finalized successfully.
[NeMo I 2025-05-15 23:43:23 nemo_logging:393] Successfully saved checkpoint from iteration      99 to /fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=2.91-step=99-consumed_samples=400.0.ckpt
[NeMo I 2025-05-15 23:43:23 nemo_logging:393] Async checkpoint save for step 100 (/fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=2.91-step=99-consumed_samples=400.0.ckpt) finalized successfully.
[NeMo I 2025-05-15 23:43:25 nemo_logging:393] Successfully saved checkpoint from iteration      99 to /fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=2.91-step=99-consumed_samples=400.0-last.ckpt
[NeMo I 2025-05-15 23:43:25 nemo_logging:393] Async checkpoint save for step 100 (/fsx-shared/bionemo/esm2/dev/checkpoints/epoch=0-val_loss=2.91-step=99-consumed_samples=400.0-last.ckpt) finalized successfully.
...
```
Once completed, we should see the `bionemo-esm2` job in `Succeeded` state as well as the `bionemo-esm2-worker-0` and `bionemo-esm2-worker-1` pods are in `Completed` one:

```bash
ubectl get pytorchjob,deploy,po,svc
NAME                                   STATE       AGE
pytorchjob.kubeflow.org/bionemo-esm2   Succeeded   4h

NAME                                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/etcd                                        1/1     1            1           4h
deployment.apps/hyperpod-dependencies-hyperpod-helm-chart   1/1     1            1           127d
deployment.apps/hyperpod-dependencies-mpi-operator          1/1     1            1           127d

NAME                                                             READY   STATUS      RESTARTS      AGE
pod/bionemo-esm2-worker-0                                        0/1     Completed   0             4h
pod/bionemo-esm2-worker-1                                        0/1     Completed   0             4h
```

We can also verify that model and training configurations and artifacts are present in the $OUTPUT_DIR by running the command via 

```bash
kubectl exec -it fsx-share-test -- ls -al /fsx-shared/bionemo/esm2/dev/checkpoints
total 140
drwxr-xr-x 5 root root 33280 May 15 23:43  .
drwxr-xr-x 3 root root 33280 May 15 23:41  ..
drwxr-xr-x 4 root root 25600 May 15 23:42 'epoch=0-val_loss=2.91-step=99-consumed_samples=400.0'
drwxr-xr-x 4 root root 25600 May 15 23:42 'epoch=0-val_loss=2.91-step=99-consumed_samples=400.0-last'
drwxr-xr-x 4 root root 25600 May 15 23:42 'epoch=0-val_loss=3.04-step=74-consumed_samples=300.0'
....
```

And, if needed, confirm that `model.yaml` is present in its subfolders:
```bash
kubectl exec -it fsx-share-test -- ls -al /fsx-shared/bionemo/esm2/dev/checkpoints/'epoch=0-val_loss=3.04-step=74-consumed_samples=300.0'/context
total 141
drwxr-xr-x 2 root root 33280 May 16 21:40 .
drwxr-xr-x 4 root root 25600 May 16 21:40 ..
-rw-r--r-- 1 root root   127 May 16 21:40 2d2e44cf-7478-40f1-8fe6-d40d73719578
-rw-r--r-- 1 root root   584 May 16 21:40 d2fe299b-b3d7-4abf-9371-84ad36c74309
-rw-r--r-- 1 root root   202 May 16 21:40 df77a1e0-8fc7-4c00-88dc-fd90e8cd2877
-rw-r--r-- 1 root root   203 May 16 21:40 f788a2eb-3392-4c3e-ba60-bba4dd4c3bbb
-rw-r--r-- 1 root root 40683 May 16 21:40 io.json
-rw-r--r-- 1 root root  8967 May 16 21:40 model.yaml
```
That confirms that model training using BioNemo tframework completed successfully..
