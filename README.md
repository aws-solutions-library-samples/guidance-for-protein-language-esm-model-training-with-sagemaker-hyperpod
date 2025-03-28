# Guidance for Protein language Evolutionary Scale Modeling (ESM) model training with NVIDIA BioNeMo framework on AWS SageMaker HyperPod

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

 **Architecture and steps for training BioNemo models on SageMaker HyperPod SLURM Cluster**

<p align="center">
<img src="assets/ref_arch_traning_hyperpod_slurm.jpg" alt="Reference Architecture HyperPod SLURM Cluster">
</p>

1. 
2.
3.

 **Architecture and steps for for provisioning SageMaker HyperPod EKS Cluster**
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

**Architecture steps for training BioNemo models on SageMaker HyperPod EKS Cluster**

<p align="center">
<img src="assets/ref_arch_traning_hyperpod_eks.jpg" alt="Reference Architecture HyperPod SLURM Cluster">
</p>
1. 
2.
3.

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



## Deployment Validation  (required)

<Provide steps to validate a successful deployment, such as terminal output, verifying that the resource is created, status of the CloudFormation template, etc.>


**Examples:**

* Open CloudFormation console and verify the status of the template with the name starting with xxxxxx.
* If deployment is successful, you should see an active database instance with the name starting with <xxxxx> in        the RDS console.
*  Run the following CLI command to validate the deployment: ```aws cloudformation describe xxxxxxxxxxxxx```



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
