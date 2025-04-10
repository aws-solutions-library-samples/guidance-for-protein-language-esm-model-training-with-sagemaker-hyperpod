# Guidance for Protein language Evolutionary Scale Modeling (ESM) model training with NVIDIA BioNeMo framework on AWS SageMaker HyperPod Clusters

This guidance aims to instruct and guide users how to pretrain popular computational drug discovery models such as Evolutionary Scale Models using the NVIDIA [BioNeMo](https://docs.nvidia.com/bionemo-framework/latest/) framework on Amazon [Sagemaker Hyperpod](https://aws.amazon.com/sagemaker-ai/hyperpod/). This guidance instructs users on how to create Sagemaker Hyperpod clusters using both [Slurm](https://slurm.schedmd.com/documentation.html) and [Kubernetes](https://kubernetes.io/) orchestrations. In addition, this guidance will showcase how to train ESM models on the HyperPod cluster.


## Table of Contents

### Required

1. [Overview](#overview-required)
    - [Architecture overview](#architecture-overview)
    - [Cost](#cost)
3. [Prerequisites](#prerequisites-required)
    - [Operating System](#operating-system-required)
4. [Deployment Steps](#deployment-steps-required)
5. [Deployment Validation](#deployment-validation-required)
6. [Running the Guidance](#running-the-guidance-required)
7. [Next Steps](#next-steps-required)
8. [Cleanup](#cleanup-required)

***Optional***

8. [FAQ, known issues, additional considerations, and limitations](#faq-known-issues-additional-considerations-and-limitations-optional)
9. [Revisions](#revisions-optional)
10. [Notices](#notices-optional)
11. [Authors](#authors-optional)

## Overview

As generative artificial intelligence (generative AI) continues to transform industries, the life sciences sector is leveraging these advanced technologies to accelerate drug discovery. Generative AI tools powered by deep learning models make it possible to analyze massive datasets, identify patterns, and generate insights to aid the search for new drug compounds. However, running these generative AI workloads requires a full-stack approach that combines robust computing infrastructure with optimized domain-specific software that can accelerate time to solution.

With the recent proliferation of new models and tools in this field, researchers are looking for help to simplify the training, customization, and deployment of these generative AI models. And our high performance computing (HPC) customers are asking for how to easily perform distributed training with these models on AWS. In this guidance, we’ll demonstrate how to pre-train the [Evolutionary Scale Modeling](https://docs.nvidia.com/bionemo-framework/2.5/models/ESM-2/) ESM-1nv model with the nVIDIA [BioNeMo](https://docs.nvidia.com/bionemo-framework/2.5/) framework using nVIDIA GPUs on [AWS SageMaker HyperPod](https://aws.amazon.com/sagemaker-ai/hyperpod/) highly available managed application platform. NVIDIA BioNeMo is a generative AI platform for drug discovery.

### NVIDIA BioNeMo

[NVIDIA BioNeMo](https://nvidia.github.io/bionemo-framework/) is a generative AI platform for drug discovery that simplifies and accelerates the training of models using your own data. BioNeMo provides researchers and developers a fast and easy way to build and integrate state-of-the-art generative AI applications across the entire drug discovery pipeline—from target identification to lead optimization—with AI workflows for 3D protein structure prediction, de novo design, virtual screening, docking, and property prediction.

The BioNeMo framework facilitates centralized model training, optimization, fine-tuning, and inferencing for protein and molecular design. Researchers can build and train foundation models from scratch at scale, or use pre-trained model checkpoints provided with the BioNeMo Framework for fine-tuning for downstream tasks. Currently, BioNeMo supports models such as ESM1nv, ESM2nv, ProtT5nv, DNABERT, OpenFold, EquiDock, DiffDock, and MegaMolBART. To read more about BioNeMo, visit the documentation page.

  
### Architecture overview
This section provides architecture diagrams and describes the components deployed with this Guidance.

 **Architecture and steps for provisioning SageMaker HyperPod SLURM Cluster**

 <p align="center">
<img src="assets/ref_arch_traning_hyperpod_slurm.jpg" alt="Reference Architecture HyperPod SLURM Cluster">
</p>

 1. Account team reserves compute capacity with [On-Demand Capacity Reservation (ODCR)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/capacity-reservation-overview.html) or [Amazon SageMaker HyperPod Flexible Training Plans](https://aws.amazon.com/about-aws/whats-new/2024/12/amazon-sagemaker-hyperpod-flexible-training-plans/)
 2. Admins/DevOps Engineers use the [AWS CloudFormation](https://aws.amazon.com/cloudformation/) stack to deploy Virtual Private Cloud (VPC) networking, [Amazon Simple Storage Service (S3)](https://aws.amazon.com/s3/) or [FSx for Lustre (FSxL)](https://aws.amazon.com/fsx/lustre/) storage and [Identity and Access Management (IAM)](https://aws.amazon.com/iam/) resources into Customer Account
 3. Admins/DevOps Engineers push [Lifecycle scripts](https://catalog.workshops.aws/sagemaker-hyperpod/en-US/01-cluster/option-b-manual-cluster-setup/02-lifecycle-scripts) to S3 bucket created in the previous step
 4. Admins/DevOps Engineers use the [AWS CLI](https://aws.amazon.com/cli/) to create the [SageMaker HyperPod](https://aws.amazon.com/sagemaker-ai/hyperpod/) cluster,including Controller Node, Compute nodes etc.
 5. Admins/DevOps Engineers generate key pair to establish access to the Controller Node of the SageMaker HyperPod cluster.
 6. Once the SageMaker HyperPod cluster is created, Admins/DevOps Engineers and Data Scientists/ML engineers can test SSH access to the Controller and Compute nodes and examine the cluster
 7. Admin/DevOps Engineers configure [IAM](https://aws.amazon.com/iam/) to use [Amazon Managed Prometheus](https://aws.amazon.com/prometheus/) to collect metrics and [Amazon Managed Grafana](https://aws.amazon.com/grafana/) for metric visualization
 8. Admin/DevOps Engineers can make further changes to the cluster using the AWS CLI


 **Architecture and steps for provisioning SageMaker HyperPod EKS Cluster**
<p align="center">
<img src="assets/ref_arch_hyperpod_eks.jpg" alt="Reference Architecture HyperPod SLURM Cluster">
</p>
 
 1. Account team reserves capacity with ODCRs or [Flexible Training Plans]((https://aws.amazon.com/about-aws/whats-new/2024/12/amazon-sagemaker-hyperpod-flexible-training-plans/)).
 2. Admin/DevOps Engineers can use eksctl ClI to provision an [Amazon EKS](https://aws.amazon.com/eks/) cluster
 3. Admin/DevOps Engineers use the Sagemaker HyperPod [VPC]((https://aws.amazon.com/vpc/)) stack to deploy Hyperpod managed node group on the EKS cluster
 4. Admin/DevOps Engineers verify access to EKS cluster and SSM access to HyperPod nodes.
 5. Admin/DevOps Engineers can install [FSx for Lustre](https://aws.amazon.com/fsx/lustre/) CSI driver and mount file system on the EKS cluster
 6. Admin/DevOps Engineers install Amazon EFA Kubernetes device plugin
 7. Admin/DevOps Engineers configures IAM to use [Amazon Managed Prometheus]((https://aws.amazon.com/prometheus/)) to collect metrics and [Amazon Managed Grafana]((https://aws.amazon.com/grafana/)) to set up the observability stack
 8. Admin/DevOps Engineers can configure [Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html) to push metrics in [Amazon Cloudwatch](https://aws.amazon.com/cloudwatch/)


### Cost


_You are responsible for the cost of the AWS services used while running this Guidance. As of <month> <year>, the cost for running this Guidance with the default settings in the <Default AWS Region (Most likely will be US East (N. Virginia)) > is approximately $<n.nn> per month for processing ( <nnnnn> records )._

Replace this amount with the approximate cost for running your Guidance in the default Region. This estimate should be per month and for processing/serving resonable number of requests/entities.

_We recommend creating a [Budget](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html) through [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/) to help manage costs. Prices are subject to change. For full details, refer to the pricing webpage for each AWS service used in this Guidance._

### Sample Cost Table ( required )


The following table provides a sample cost breakdown for deploying this Guidance with the default parameters in the US East (N. Virginia) Region for one month.
As of March, 2025 the cost for running this Guidance with the default settings in the US East (N. Virginia) region is approximately **$4043.18 per month** 

| AWS service  |   Dimensions   |  Cost [USD] / month |
| ----------- | --------------- | ------------ |
|   Compute   |   4xg5.12xlarge |   2235.90    |
|   Compute   |   1xm5.12xlarge |    852.64    |
|   Storage   |   S3 (100GB)    |     11.50    |
|   Storage   |   EBS (500GB)   |    250.00    |
|   Storage   |   FSx (1.2TB)    |   720.07    |
|   Network   | VPC, Subnets, NAT Gateway, VPC Endpoints | 596.85|
|   Total   |      |   4043.18    |

## Prerequisites 

### Operating System 

- Talk about the base Operating System (OS) and environment that can be used to run or deploy this Guidance, such as *Mac, Linux, or Windows*. Include all installable packages or modules required for the deployment. 
- By default, assume Amazon Linux 2/Amazon Linux 2023 AMI as the base environment. All packages that are not available by default in AMI must be listed out.  Include the specific version number of the package or module.

**Example:**
“These deployment instructions are optimized to best work on **<Amazon Linux 2 AMI>**.  Deployment in another OS may require additional steps.”

- Include install commands for packages, if applicable.


### Third-party tools (If applicable)

*List any installable third-party tools required for deployment.*


### AWS account requirements (If applicable)

*List out pre-requisites required on the AWS account if applicable, this includes enabling AWS regions, requiring ACM certificate.*

**Example:** “This deployment requires you have public ACM certificate available in your AWS account”

**Example resources:**
- ACM certificate 
- DNS record
- S3 bucket
- VPC
- IAM role with specific permissions
- Enabling a Region or service etc.


### aws cdk bootstrap (if sample code has aws-cdk)

<If using aws-cdk, include steps for account bootstrap for new cdk users.>

**Example blurb:** “This Guidance uses aws-cdk. If you are using aws-cdk for first time, please perform the below bootstrapping....”

### Service limits  (if applicable)

<Talk about any critical service limits that affect the regular functioning of the Guidance. If the Guidance requires service limit increase, include the service name, limit name and link to the service quotas page.>

### Supported Regions (if applicable)

<If the Guidance is built for specific AWS Regions, or if the services used in the Guidance do not support all Regions, please specify the Region this Guidance is best suited for>


## Deployment Steps (required)

Deployment steps must be numbered, comprehensive, and usable to customers at any level of AWS expertise. The steps must include the precise commands to run, and describe the action it performs.

* All steps must be numbered.
* If the step requires manual actions from the AWS console, include a screenshot if possible.
* The steps must start with the following command to clone the repo. ```git clone xxxxxxx```
* If applicable, provide instructions to create the Python virtual environment, and installing the packages using ```requirement.txt```.
* If applicable, provide instructions to capture the deployed resource ARN or ID using the CLI command (recommended), or console action.

 
**Example:**

1. Clone the repo using command ```git clone xxxxxxxxxx```
2. cd to the repo folder ```cd <repo-name>```
3. Install packages in requirements using command ```pip install requirement.txt```
4. Edit content of **file-name** and replace **s3-bucket** with the bucket name in your account.
5. Run this command to deploy the stack ```cdk deploy``` 
6. Capture the domain name created by running this CLI command ```aws apigateway ............```

### Training Evolutionary Scale Models (ESM2) model on HyperPod SLURM cluster:

**Architecture and steps for training BioNemo models on SageMaker HyperPod SLURM Cluster**

<p align="center">
<img src="assets/ref_arch_traning_hyperpod_slurm.jpg" alt="Reference Architecture HyperPod SLURM Cluster">
</p>

1. 
2.
3.


[NVIDIA BioNeMo](https://docs.nvidia.com/bionemo-framework/latest/) is a domain-specific machine learning framework for training and using foundation models for biology. This includes models for analyzing proteins, small molecules, and other biological molecules. To see the latest models available in BioNeMo 2.5 see [here](https://docs.nvidia.com/bionemo-framework/latest/models/).

Below are instructions to pretrain [ESM2](https://docs.nvidia.com/bionemo-framework/latest/models/ESM-2/) models with NVIDIA BioNeMo on Sagemaker HyPerPod slurm clusters.

0. Prerequisites

Have a slurm based Sagemaker HyperPod cluster with Nvidia GPUs.

1. Setup environment variables

SSH into the head or login node of your cluster and run:

```
# Path to save training data and checkpoints
export TARGET_PATH=/fsx/ubuntu/bionemo
export DOCKER_IMAGE_NAME=bionemo
```

2. Clone this GitHub repo

```bash
cd ${TARGET_PATH}
git clone https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework.git

cd guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework/source/hyperpod_slurm
chmod 777 *.sh
```

3. Build Docker Image

We provide an AWS optimized Docker image that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly:

```bash
./build.sh
```

4. Build Enroot Image

[NVIDIA Enroot](https://github.com/NVIDIA/enroot) is a lightweight container runtime that allows users to run containerized applications without requiring full-fledged container engines like Docker. It is designed for HPC environments, particularly the Slurm Workload Manager. To convert Docker images to Enroot squash files:

```bash
./enroot.sh
```

5. Download Model traning data

BioNeMo 2.5 container provides a CLI `download_bionemo_data` to download test or full UniProt dataset from NVIDIA Catalog which we can run as below. 
`get-data.sh` script runs a container based on the customizd BioNemo container image created above, runs the `download_bionemo_data` CLI to download test data and kills the container when done and saves `_sanity.tar.gz` compressed file (71M) and `_sanity.tar.gz.untar` (134M) with training and validation data.

```bash
./get-data.sh
```

6. Pretrain ESM2 models using SLURM scheduler

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
Upon completion of ESM model training job, we should be able to see entries in the shared data directory on the FSX Lustre file system:

```bash
ls -l /fsx-shared/processed
total 679472
-rw-r--r-- 1 root root  11916956 Jan 17 14:54 __indexmap_32000mns_512msl_0.00ssp_1234s.npy
-rw-r--r-- 1 root root 792260744 Jan 17 12:42 __indexmap_64000000mns_512msl_0.00ssp_1234s.npy
-rw-r--r-- 1 root root  76860128 Jan 17 13:58 __indexmap_6403200mns_512msl_0.00ssp_1234s.npy
drwxr-xr-x 3 root root     33280 Jan 17 12:41 fsx
drwxr-xr-x 2 root root     41472 Jan 17 14:53 test
drwxr-xr-x 2 root root     41472 Jan 17 12:41 train
drwxr-xr-x 2 root root     41472 Jan 17 13:58 val
```  

### Training Evolutionary Scale Models (ESM2) model on HyperPod EKS cluster:

**Architecture steps for training BioNemo models on SageMaker HyperPod EKS Cluster**

<p align="center">
<img src="assets/ref_arch_traning_hyperpod_eks.jpg" alt="Reference Architecture HyperPod EKS Cluster">
</p>
1. 
2.
3.


[NVIDIA BioNeMo](https://docs.nvidia.com/bionemo-framework/latest/) is a domain-specific machine learning framework for training and using foundation models for biology. This includes models for analyzing proteins, small molecules, and other biological molecules. To see the latest models available in BioNeMo 2.5 see [here](https://docs.nvidia.com/bionemo-framework/latest/models/).
Below are step by step instructions to pretrain [ESM2](https://docs.nvidia.com/bionemo-framework/latest/models/ESM-2/) models with NVIDIA BioNeMo on Sagemaker HyPerPod EKS clusters.

0. Prerequisites

Have a EKS based Sagemaker HyperPod cluster with nVidia GPUs. You can verify actually available number of GPUs and number of connected EFA devices like below:

```bash
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,INSTANCETYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa"

NAME                           INSTANCETYPE     GPU   EFA
hyperpod-i-048cd15160ee28917   ml.p5.48xlarge   8     32
hyperpod-i-09539ee1dd9971647   ml.p5.48xlarge   8     32
```

1. Setup environment variables

SSH into a machine that has full access to your HyperPod EKS cluster and run:

```
# Path to save training data and checkpoints
export AWS_REGION=us-east-1
export DOCKER_IMAGE_NAME=bionemo
export TAG=:aws
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/

# Settings below depend on actual GPU capacity and EFA setting per selected GPU nodes and may vary
export GPU_PER_NODE=8
export EFA_PER_NODE=32

export NUM_NODES=2
export OUTPUT_DIR=/fsx-shared
```

2. Clone this GitHub repo

```bash
git clone https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework.git

cd guidance-for-protein-language-esm-model-training-with-nvidia-bionemo-framework/source/hyperpod_eks
chmod 777 *.sh
```
3. Build and push Docker Image

We provide an AWS optimized Docker image that sets up networking components (EFA, AWS-OFI-NCCL) for a multi-node cluster correctly:

```bash
./build.sh
```
Once built you can push the Docker image to ECR as follows:

```bash
./push.sh
```

4. Download Model Training data

BioNeMo 2.5 container provides a CLI `download_bionemo_data` to download test or full UniProt dataset from NVIDIA Catalog which we can run as below. To that end we provide a `get-data-template.yaml`. First substitute the environment variables to generate `get-data.yaml` like below:

```bash
cat get-data-template.yaml | envsubst > get-data.yaml
```

And then run the training job as below. The pod will take roughly 6 minutes to start as it is a roughly 35GB image.

```bash
kubectl apply -f get-data.yaml
```
Upon completion of Model training data import that pod should be in `Complete` state:
```bash
kubectl get po
NAME                                                         READY   STATUS      RESTARTS         AGE
download-bionemo-data                                        0/1     Completed   10 (5m18s ago)   26m
fsx-share-test                                               1/1     Running     0                43h
```

To verify that the Model data is available in the filesystem, we need a dummy pod with the filesystem mounted. To do so, we provide the `view-fsx.yaml` which creates a pod called `fsx-share-test`. To view the contents of the file system we can exec into that pod as shown below:

```bash
# Create the dummy pod
kubectl apply -f view-fsx.yaml
# Exec in the pod
kubectl exec fsx-share-test -- ls -l /fsx-shared
total 72040
-rw-r--r-- 1 root root 73307674 Apr  9 18:51 006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz
drwxr-xr-x 3 root root    25600 Apr  9 18:51 006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar
```

Once completed, export the `DATA_DIR` as an environment variable as below using the `*.untar` folder name:

```
export DATA_DIR=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar
```

5. Pretrain ESM2 models

Now we are ready to submit distributed training jobs to pretrain `ESM2` models. We provide the `esm2-pretrain-template.yaml` script to run training on two `ml.p5.48xlarge` nodes with `8xH100 80 GB` GPUs (or a similar GPU based nodes like `ml.g5.48xlarge`) 
Make sure data paths and model configuration is correct if you are running on custom data. To kick off distributed training job execute:

```bash
# populate values from environment variables into the pretrain job template
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
              image: XXXXXXXXXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/bionemo:aws
              resources:
                requests:
                  nvidia.com/gpu: 8
                  vpc.amazonaws.com/efa: 32
                limits:
                  nvidia.com/gpu: 8
                  vpc.amazonaws.com/efa: 32
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
                - --train-cluster-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/train_clusters_sanity.parquet
                - --train-database-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/train_sanity.db
                - --valid-cluster-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/valid_clusters.parquet
                - --valid-database-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/validation.db
                - --precision=bf16-mixed
                - --num-gpus=8
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
```
Then initiate the pretrain job by applying that Deployment and PyTorchJob onti our EKS HyperPod cluster:

```bash
kubectl apply -f esm2-pretrain.yaml
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/bionemo-esm2 created
```

That should deploy an `etcd` key-value database deployment and pod and `bionemo-esm2` related pods that carry out PyTorchJob

## Deployment Validation 

<Provide steps to validate a successful deployment, such as terminal output, verifying that the resource is created, status of the CloudFormation template, etc.>
To validate that ESM2 pre-training job is actually running on HyperPod EKS cluster, check the K8s objects in the `default` namespace that should have been deployed

```bash
#first check if a PyTorchJob object has been created and is running:
kubectl get pytorchjob
NAME           STATE     AGE
bionemo-esm2   Running   20m

#Then get details about Deployments, pods and services
kubectl get deploy,po,svc
NAME                                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/etcd                                        1/1     1            1           14s
deployment.apps/hyperpod-dependencies-hyperpod-helm-chart   1/1     1            1           92d
deployment.apps/hyperpod-dependencies-mpi-operator          1/1     1            1           92d

NAME                                                             READY   STATUS              RESTARTS        AGE
pod/bionemo-esm2-worker-0                                        0/1     ContainerCreating   0               14s
pod/bionemo-esm2-worker-1                                        0/1     ContainerCreating   0               14s
pod/etcd-6cd66c884c-9b7fh                                        1/1     Running             0               14s
pod/fsx-share-test                                               1/1     Running             0               2m29s
pod/hyperpod-dependencies-aws-efa-k8s-device-plugin-5dgxv        1/1     Running             1 (3m48s ago)   2d5h
pod/hyperpod-dependencies-aws-efa-k8s-device-plugin-c8v6w        1/1     Running             0               6h46m
```
It takes a while to download previously built and uploaded to ECR customized BioNemo 2.5 container image. You can check status of each `bionemo-esm2-worker` pod by running commands like:

```bash
kubectl describe po bionemo-esm2-worker-0
---------
Name:             bionemo-esm2-worker-0
Namespace:        defaultPriority:         0
Service Account:  defaultNode:             hyperpod-i-0ad7ba010d6cbdc38/10.1.250.6
Start Time:       Thu, 10 Apr 2025 04:50:05 +0000Labels:           training.kubeflow.org/job-name=bionemo-esm2
                  training.kubeflow.org/operator-name=pytorchjob-controller                  training.kubeflow.org/replica-index=0
                  training.kubeflow.org/replica-type=worker
Annotations:      sidecar.istio.io/inject: false
Status:           RunningIP:               10.1.0.44
IPs:  IP:           10.1.0.44
Controlled By:  PyTorchJob/bionemo-esm2Containers:
  pytorch:    Container ID:  containerd://65487da33d5b5f2609e2c4058211573e323402d1da7a94be40bbeacf8798541a
    Image:         XXXXXXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/bionemo:aws    Image ID:      354918380621.dkr.ecr.us-east-1.amazonaws.com/bionemo@sha256:9df8db0cfac9eb88c308c8a8f944e2622a493856c6fa6bc868340e853e66f905
    Port:          23456/TCP    Host Port:     0/TCP
    Command:      python3
      /workspace/bionemo2/sub-packages/bionemo-esm2/src/bionemo/esm2/scripts/train_esm2.py
      --train-cluster-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/train_clusters_sanity.parquet
      --train-database-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/train_sanity.db
      --valid-cluster-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/valid_clusters.parquet
      --valid-database-path=/fsx-shared/006911f92bbc0ded7ea302bbdbfab4c694b409e699c32fd49de1c527a99dba3e-2024_03_sanity.tar.gz.untar/2024_03_sanity/validation.db
      --precision=bf16-mixed
      --num-gpus=8
      --num-nodes=2
      --num-steps=100
      --val-check-interval=25
      --max-seq-length=1024
      --limit-val-batches=2
      --micro-batch-size=2
      --num-layers=33
      --hidden-size=1280
      --num-attention-head=20
      --ffn-hidden-size=5120
      --tensor-model-parallel-size=1
      --create-tensorboard-logger
      --result-dir=/fsx-shared
    State:          Running
      Started:      Thu, 10 Apr 2025 04:56:41 +0000
    Ready:          True
    Restart Count:  0
    Limits:
      nvidia.com/gpu:         8
      vpc.amazonaws.com/efa:  1
    Requests:
      nvidia.com/gpu:         8
      vpc.amazonaws.com/efa:  1
    Environment:
      NCCL_DEBUG:         INFO
      PYTHONUNBUFFERED:   1
      PET_RDZV_ENDPOINT:  etcd:2379
      PET_RDZV_BACKEND:   etcd
      PET_NNODES:         1:64
      PET_MAX_RESTARTS:   100
    Mounts:
      /fsx-shared from fsx-pv-storage (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-2ghvm (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       True
  ContainersReady             True
  PodScheduled                True
Volumes:
  fsx-pv-storage:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  fsx-claim
    ReadOnly:   false
  kube-api-access-2ghvm:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
                             nvidia.com/gpu:NoSchedule op=Exists
                             vpc.amazonaws.com/efa:NoSchedule op=Exists
Events:
  Type    Reason     Age    From               Message
  ----    ------     ----   ----               -------
  Normal  Scheduled  7m13s  default-scheduler  Successfully assigned default/bionemo-esm2-worker-0 to hyperpod-i-0ad7ba010d6cbdc38
  Normal  Pulling    7m13s  kubelet            Pulling image "354918380621.dkr.ecr.us-east-1.amazonaws.com/bionemo:aws"
  Normal  Pulled     42s    kubelet            Successfully pulled image "354918380621.dkr.ecr.us-east-1.amazonaws.com/bionemo:aws" in 6m31.174s (6m31.174s including waiting). Image size: 16677241606 bytes.
  Normal  Created    41s    kubelet            Created container pytorch
  Normal  Started    38s    kubelet            Started container pytorch
```
The last 2 lines confirm that contaier `pytorch` in that pod has started. Similar command can be run for `bionemo-esm2-worker-0`
In order to monitor training jobs in real-time you can run commands to tail the logs of running containers like:

```bash
kubectl logs -f bionemo-esm2-worker-0
---
...
[WARNING  | py.warnings        ]: /usr/local/lib/python3.12/dist-packages/mamba_ssm/distributed/tensor_parallel.py:25: FutureWarning: `torch.cuda.amp.custom_fwd(args...)` is deprecated. Please use `torch.amp.custom_fwd(args..., device_type='cuda')` instead.
  @custom_fwd
[WARNING  | py.warnings        ]: /usr/local/lib/python3.12/dist-packages/mamba_ssm/distributed/tensor_parallel.py:61: FutureWarning: `torch.cuda.amp.custom_bwd(args...)` is deprecated. Please use `torch.amp.custom_bwd(args..., device_type='cuda')` instead.
  @custom_bwd
[WARNING  | py.warnings        ]: /usr/local/lib/python3.12/dist-packages/mamba_ssm/ops/triton/ssd_combined.py:757: FutureWarning: `torch.cuda.amp.custom_fwd(args...)` is deprecated. Please use `torch.amp.custom_fwd(args..., device_type='cuda')` instead.
  @custom_fwd
[WARNING  | py.warnings        ]: /usr/local/lib/python3.12/dist-packages/mamba_ssm/ops/triton/ssd_combined.py:835: FutureWarning: `torch.cuda.amp.custom_bwd(args...)` is deprecated. Please use `torch.amp.custom_bwd(args..., device_type='cuda')` instead.
  @custom_bwd

Initializing distributed: GLOBAL_RANK: 2, MEMBER: 3/16
Initializing distributed: GLOBAL_RANK: 1, MEMBER: 2/16
Initializing distributed: GLOBAL_RANK: 5, MEMBER: 6/16
Initializing distributed: GLOBAL_RANK: 6, MEMBER: 7/16
..
```

## Running the Guidance (required)

<Provide instructions to run the Guidance with the sample data or input provided, and interpret the output received.> 

This section should include:

* Guidance inputs
* Commands to run
* Expected output (provide screenshot if possible)
* Output description

## Next Steps (required)

Provide suggestions and recommendations about how customers can modify the parameters and the components of the Guidance to further enhance it according to their requirements.


## Cleanup (required)

- Include detailed instructions, commands, and console actions to delete the deployed Guidance.
- If the Guidance requires manual deletion of resources, such as the content of an S3 bucket, please specify.



## FAQ, known issues, additional considerations, and limitations (optional)


**Known issues (optional)**

<If there are common known issues, or errors that can occur during the Guidance deployment, describe the issue and resolution steps here>


**Additional considerations (if applicable)**

<Include considerations the customer must know while using the Guidance, such as anti-patterns, or billing considerations.>

**Examples:**

- “This Guidance creates a public AWS bucket required for the use-case.”
- “This Guidance created an Amazon SageMaker notebook that is billed per hour irrespective of usage.”
- “This Guidance creates unauthenticated public API endpoints.”


Provide a link to the *GitHub issues page* for users to provide feedback.

**Example:** *“For any feedback, questions, or suggestions, please use the issues tab under this repo.”*

## Revisions (optional)

Document all notable changes to this project.

Consider formatting this section based on Keep a Changelog, and adhering to Semantic Versioning.

## Notices (optional)

Include a legal disclaimer

**Example:**
*Customers are responsible for making their own independent assessment of the information in this Guidance. This Guidance: (a) is for informational purposes only, (b) represents AWS current product offerings and practices, which are subject to change without notice, and (c) does not create any commitments or assurances from AWS and its affiliates, suppliers or licensors. AWS products or services are provided “as is” without warranties, representations, or conditions of any kind, whether express or implied. AWS responsibilities and liabilities to its customers are controlled by AWS agreements, and this Guidance is not part of, nor does it modify, any agreement between AWS and its customers.*


## Authors (optional)

Name of code contributors
