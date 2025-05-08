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
    image: 354918380621.dkr.ecr.us-east-1.amazonaws.com/bionemo:aws
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
          containers:
            - name: pytorch
              image: 354918380621.dkr.ecr.us-east-1.amazonaws.com/bionemo:aws
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
                - "python3"
                - /workspace/bionemo2/sub-packages/bionemo-esm2/src/bionemo/esm2/scripts/train_esm2.py
                - --train-cluster-path=006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/train_clusters_sanity.parquet
                - --train-database-path=006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/train_sanity.db
                - --valid-cluster-path=006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/valid_clusters.parquet
                - --valid-database-path=006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/validation.db
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
To tail ESM model training pod logs, you can run the following command:
```bash
INFO     | pytorch_lightning.utilities.rank_zero]: Trainer already configured with model summary callbacks: [<class 'lightning.pytorch.callbacks.rich_model_summary.RichModelSummary'>]. Skipping setting a default `ModelSummary` callback.
[INFO     | pytorch_lightning.utilities.rank_zero]: GPU available: True (cuda), used: True
[INFO     | pytorch_lightning.utilities.rank_zero]: TPU available: False, using: 0 TPU cores
[INFO     | pytorch_lightning.utilities.rank_zero]: HPU available: False, using: 0 HPUs
[NeMo W 2025-05-06 23:48:47 nemo_logging:405] WandB is currently turned off.
[NeMo W 2025-05-06 23:48:47 nemo_logging:405] User-set tensorboard is currently turned off. Internally one may still be set by NeMo2.
[NeMo I 2025-05-06 23:48:47 nemo_logging:393] Experiments will be logged at /fsx-shared/bionemo/esm2/dev
[NeMo W 2025-05-06 23:48:47 nemo_logging:405] "update_logger_directory" is True. Overwriting tensorboard logger "save_dir" to /fsx-shared/bionemo
[NeMo W 2025-05-06 23:48:47 nemo_logging:405] The Trainer already contains a ModelCheckpoint callback. This will be overwritten.
[NeMo W 2025-05-06 23:48:47 nemo_logging:405] The checkpoint callback was told to monitor a validation value and trainer's max_steps was set to 100. Please ensure that max_steps will run for at least 1 epochsto ensure that checkpointing will not error out.
[NeMo I 2025-05-06 23:48:47 nemo_logging:393] Rank 0 has data parallel group : [0, 1]
[NeMo I 2025-05-06 23:48:47 nemo_logging:393] Rank 0 has combined group of data parallel and context parallel : [0, 1]
[NeMo I 2025-05-06 23:48:47 nemo_logging:393] All data parallel group ranks with context parallel combined: [[0, 1]]
[NeMo I 2025-05-06 23:48:47 nemo_logging:393] Ranks 0 has data parallel rank: 0
[NeMo I 2025-05-06 23:48:47 nemo_logging:393] Rank 0 has context parallel group: [0]
......
[NeMo I 2025-05-06 23:48:47 nemo_logging:393] All embedding group ranks: [[0], [1]]
[NeMo I 2025-05-06 23:48:47 nemo_logging:393] Rank 0 has embedding rank: 0
Initializing distributed: GLOBAL_RANK: 0, MEMBER: 1/2
.....
```
Once completed, we should see the `bionemo-esm2` job in `Completed` state as well as the `bionemo-esm2-worker-0` and `bionemo-esm2-worker-1` pods

We can also verify that model and training configurations are present at the $OUTPUT_DIR by running the command via 

```bash
kubectl exec -it fsx-share-test -- ls -al /fsx-shared/bionemo/esm2
---
total 98
drwxr-xr-x 3 root root 33280 May  6 23:48 .
drwxr-xr-x 3 root root 33280 May  6 23:48 ..
drwxr-xr-x 2 root root 33280 May  6 23:48 dev
```
