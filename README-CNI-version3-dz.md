Guidance for AWS Network Firewall cross-network traffic inspection
(formerly known as Centralized Network Inspection on AWS)

## Table of Contents 


1.  [Overview](#overview)
    - [Cost](#cost)
2.  [Prerequisites](#prerequisites)
    - [Operating System](#operating-system)
3.  [Deployment Steps](#deployment-steps)
4.  [Deployment Validation](#deployment-validation)
5.  [Running the Guidance](#running-the-guidance)
6.  [Next Steps](#next-steps)
7.  [Cleanup](#cleanup)

<!-- -->

8.  [FAQ, known issues, additional considerations, and
    limitations](#Xfbf0e9412269b8543c5349bec02f30340f25947)
9.  [Notices](#notices)

## Overview

> **Guidance for AWS Network Firewall cross-network traffic inspection
> (formerly** Centralized Network Inspection on AWS) configures the AWS
> resources needed to filter network traffic.
>
> This solution saves you time by automating the process of provisioning
> a centralized AWS Network Firewall to inspect traffic between your
> Amazon Virtual Private Clouds (Amazon VPCs).

**Architecture**

![](./media/image1.png){width="6.667244094488189in"
height="3.7503248031496064in"}

### Cost

> You are responsible for the cost of the AWS services used while
> running this solution. As of this revision, the cost for running this
> solution with the default settings in the US East (N. Virginia) Region
> is approximately **\$620.55 per month**. These costs are for the
> resources shown in the [[Sample cost
> table]{.underline}](#_bookmark11).
>
> We recommend creating a
> [[budget]{.underline}](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html)
> through [[AWS Cost
> Explorer]{.underline}](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)
> to help manage costs. Prices are subject to change. For full details,
> see the pricing webpage for each [[AWS service used in
> this]{.underline}](#_bookmark6) [[solution]{.underline}](#_bookmark6).

### Cost Table

**Note : Once you have created a sample cost table using AWS Pricing
Calculator, copy the cost breakdown to below table and upload a PDF of
the cost estimation on BuilderSpace. Do not add the link to the pricing
calculator in the ReadMe.**

The following table provides a sample cost breakdown for deploying this
Guidance with the default parameters in the US East (N. Virginia) Region
for one month.

+---------------------------------+-----------------------------+---------------------------+
| AWS service                     | Dimensions                  | Cost \[USD\]              |
+=================================+=============================+===========================+
| > AWS Network Firewall          | (\$0.395/endpoint/hour)     |                           |
| > (endpoint)                    |                             |                           |
+---------------------------------+-----------------------------+---------------------------+
| > AWS Network Firewall (data    | 5 GB (\$0.65/GB)            | \$9.75                    |
| > processed)                    |                             |                           |
+---------------------------------+-----------------------------+---------------------------+
| > AWS Transit Gateway (VPC      | 24 hours (\$0.05/hour)      | \$36.00                   |
| > attachment)                   |                             |                           |
+---------------------------------+-----------------------------+---------------------------+
| > AWS Transit Gateway (data     | 10 GB (\$0.02/GB)           | \$6.00                    |
| > processed)                    |                             |                           |
+---------------------------------+-----------------------------+---------------------------+
| > Amazon CodePipeline           |                             | Depends on number of      |
|                                 |                             | CodePipeline executions   |
+---------------------------------+-----------------------------+---------------------------+
| > Amazon CodeBuild              |                             | Depends on number of      |
|                                 |                             | CodePipeline executions   |
+---------------------------------+-----------------------------+---------------------------+
| > Amazon CodeCommit             |                             | Depends on number of      |
|                                 |                             | CodePipeline executions   |
+---------------------------------+-----------------------------+---------------------------+
| > Amazon S3                     |                             | Depends on number of      |
|                                 |                             | CodePipeline executions   |
|                                 |                             | and Network Firewall log  |
|                                 |                             | activity                  |
+---------------------------------+-----------------------------+---------------------------+
|                                 | Total                       | \$620.55                  |
+---------------------------------+-----------------------------+---------------------------+

## Prerequisites 

### Operating System 

Node.js\>16

### AWS account requirements

Supported Regions This solution uses Network Firewall, which is not
currently available in all AWS Regions. You must launch this solution in
an AWS Region where AWS Network Firewall is available. For the most
current availability of AWS services by Region, see the [[AWS Regional
Services
List]{.underline}](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/).

![](./media/image2.png)

## Deployment Steps

[]{#deployment-validation-required .anchor}The high-level process ﬂow
for the solution components deployed with the CloudFormation template is
as follows:

1.  The CloudFormation template deploys an [[inspection
    VPC]{.underline}](https://aws.amazon.com/blogs/networking-and-content-delivery/deployment-models-for-aws-network-firewall/)
    with four subnets in randomly- selected Availability Zones in the
    Region where the solution is deployed.

    a.  The solution uses two of the subnets to create [[AWS Transit
        Gateway]{.underline}](https://aws.amazon.com/transit-gateway/)
        attachments for your VPCs if you provide an existing transit
        gateway ID.

    b.  The solution uses the other two subnets to create [[AWS Network
        Firewall]{.underline}](https://aws.amazon.com/network-firewall/)
        endpoints in two randomly-selected Availability Zones in the
        Region where the solution is deployed.

2.  The CloudFormation template creates a new [[AWS
    CodeCommit]{.underline}](https://aws.amazon.com/codecommit/)
    repository and a default network ﬁrewall conﬁguration that allows
    all traﬃc. This initiates [[AWS
    CodePipeline]{.underline}](https://aws.amazon.com/codepipeline/) to
    run the following stages:

![](./media/image2.png)

a.  Validation stage -- The solution validates the Network Firewall
    conﬁguration by using Network Firewall application programming
    interfaces (APIs) with dry run mode enabled. This allows the user to
    ﬁnd unexpected issues before attempting an actual change. This stage
    also checks whether all the referenced ﬁles in the conﬁguration
    exist in the JSON ﬁle structure.

b.  Deployment stage -- The solution creates a new
    [[ﬁrewall]{.underline}](https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewalls.html),
    [[ﬁrewall
    policy]{.underline}](https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewall-policies.html),
    and [[rule
    groups]{.underline}](https://docs.aws.amazon.com/network-firewall/latest/developerguide/rule-groups.html).
    If any of the resources already exist, the solution updates the
    resources. This stage also helps with detecting any changes and
    remediates by applying the latest conﬁguration from the CodeCommit
    repository. The rule group changes roll back to the original state
    if one of the rule group changes fails. The appliance mode activates
    for the Transit Gateway to
    [[Amazon]{.underline}](https://aws.amazon.com/vpc/)
    [[VPC]{.underline}](https://aws.amazon.com/vpc/) attachment to avoid
    asymmetric traﬃc. For more information, refer to [[Appliance in
    a]{.underline}](https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-appliance-scenario.html)
    [[shared services
    VPC]{.underline}](https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-appliance-scenario.html).

<!-- -->

3.  The solution creates Amazon VPC route tables for each Availability
    Zone. The default route destination target for each is the Amazon
    VPC endpoint for Network Firewall.

4.  The solution creates a shared route table with ﬁrewall subnets. The
    default route destination target is the transit gateway ID. This
    route is only created if the transit gateway ID is provided in the
    CloudFormation input parameters.

Follow the steps for deploying your custom version of the solution.

- Create an S3 bucket with the bucket appended with the region in which
  the deployment is to be made. example, if the deployment is to be made
  in us-east-1 create a bucket name as \[BUCKET_NAME\]-us-east-1.

- Create the distribution files using the script provided in the build
  section above.

- Create the S3 Key in the bucket
  centralized-network-inspection/\[VERSION_ID\]/

- Create the S3 Key in the bucket centralized-network-inspection/latest/

- Copy the file
  ./deployment/regional-s3-assets/centralized-network-inspection.zip to
  the location
  s3://\[BUCKET_NAME\]-\[REGION\]/centralized-network-inspection/\[VERSION_ID\]/

- Copy the file
  ./deployment/regional-s3-assets/centralized-network-inspection-configuration.zip
  to the location
  s3://\[BUCKET_NAME\]-\[REGION\]/centralized-network-inspection/latest/

Once the above steps are completed, use the file
./deployment/global-s3-assets/centralized-network-inspection-on-aws.template
to create a stack in CloudFormation.

1.  Build the CDK code

> cd source/
>
> npm run build

2.  Build the Centralized Network Inspection Solution CodeBuild source
    code

> cd source/centralizedNetworkInspection
>
> tsc

3.  Build the templates for custom deployments

> cd deployments/
>
> chmod +x ./build-s3-dist.sh
>
> ./build-s3-dist.sh \[SOLUTION_DIST_BUCKET\]
> centralized-network-inspection \[VERSION_ID\]

## Deployment Validation

> []{#running-the-guidance-required .anchor}cd \<rootDir\>/deployment
>
> chmod +x ./run-unit-tests.sh
>
> ./run-unit-tests.sh

## Next Steps

Provide suggestions and recommendations about how customers can modify
the parameters and the components of the Guidance to further enhance it
according to their requirements.

## Cleanup

> []{#Xfbf0e9412269b8543c5349bec02f30340f25947 .anchor}Uninstall the
> solution from the AWS Management Console or by using the [[AWS
> Command]{.underline}](https://aws.amazon.com/cli/) [[Line
> Interface]{.underline}](https://aws.amazon.com/cli/) (AWS CLI).
> Manually delete [[several
> resources]{.underline}](#manually-uninstalling-resources) created by
> this solution. This solution doesn\'t automatically delete these
> resources in case you have stored data to retain.

### Using the AWS Management Console

1.  Sign in to the [[CloudFormation
    console]{.underline}](https://console.aws.amazon.com/cloudformation/home).

2.  On the **Stacks** page, select this solution\'s installation stack.

3.  Choose **Delete**.

### Using AWS Command Line Interface

> Determine whether the AWS CLI is available in your environment. For
> installation instructions,
>
> see [[What Is the AWS Command Line
> Interface]{.underline}](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html)
> in the *AWS CLI User Guide*. After conﬁrming that the AWS CLI is
> available, run the following command.

### Manually uninstalling resources

> The following resources will be retained even after the solution is
> deleted. Refer to the following links to manually delete the
> resources:

- [[AWS CodeCommit
  repository]{.underline}](https://docs.aws.amazon.com/codecommit/latest/userguide/how-to-delete-repository.html)

- [[Amazon CloudWatch log
  groups]{.underline}](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html)

- [[Amazon S3 CodePipeline artifact
  bucket]{.underline}](https://docs.aws.amazon.com/AmazonS3/latest/userguide/delete-bucket.html)

- [[Amazon S3 CodeBuild source code
  bucket]{.underline}](https://docs.aws.amazon.com/AmazonS3/latest/userguide/delete-bucket.html)

- [[AWS Network
  Firewall]{.underline}](https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewall-deleting.html)

- [[AWS Network Firewall ﬁrewall
  policy]{.underline}](https://docs.aws.amazon.com/network-firewall/latest/developerguide/firewall-policy-deleting.html)

- [[AWS Network Firewall rule
  groups]{.underline}](https://docs.aws.amazon.com/network-firewall/latest/developerguide/rule-group-deleting.html)

- [[Inspection
  VPC]{.underline}](https://docs.aws.amazon.com/vpc/latest/userguide/working-with-vpcs.html#VPC_Deleting)

- [[AWS Transit Gateway
  attachment]{.underline}](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html#delete-vpc-attachment)

## FAQ, known issues, additional considerations, and limitations

**Known issues**

### Problem: Missing Network Firewall resources

> The CloudFormation stack has completed successfully, but not all the Network Firewall resources are created.

#### Resolution

> After the CloudFormation stack is complete, the CodePipeline stage
> created by the solution might still be in the In-Progress state. Once
> the CodePipeline stage is completed, all the Network Firewall
> resources will be available in the AWS Network Firewall console.

### Problem: Failed CodePipeline stage

> The CodePipeline stage is failing.

#### Resolution

> If the CodePipeline stage is in Failed state, it means that this
> solution hasn\'t been able to complete the create or update network
> ﬁrewall resources operation. Refer to the logs in the CodePipeline
> stages to ensure that the CodeBuild stages are successful.
>
> If a JSON ﬁle is not valid or has incorrect information, the CodeBuild
> stage that validates the ﬁles will list the errors along with the ﬁle
> names.
>
> For more information, refer to the [[AWS CodeBuild User Guide]{.underline}](https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html).

## Notices

Legal disclaimer

**Example:** *Customers are responsible for making their own independent assessment of the information in this Guidance. This Guidance: (a) is
for informational purposes only, (b) represents AWS current product offerings and practices, which are subject to change without notice, and
(c) does not create any commitments or assurances from AWS and its affiliates, suppliers or licensors. AWS products or services are
provided "as is" without warranties, representations, or conditions of any kind, whether express or implied. AWS responsibilities and
liabilities to its customers are controlled by AWS agreements, and this Guidance is not part of, nor does it modify, any agreement between AWS
and its customers.*
