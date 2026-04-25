#  Multi-Region Blue/Green Deployment (Disaster Recovery Architecture)

##  Project Summary

Designed and implemented a multi-region, highly available web application deployment architecture on AWS using a blue/green deployment strategy. The system is built to support disaster recovery through an active-passive setup across regions, with automated failover and zero-downtime deployments.

---

##  Key Outcomes

- Implemented multi-region infrastructure (Primary + Failover)  
- Designed disaster recovery strategy using Route 53 health checks  
- Automated infrastructure provisioning using CloudFormation  
- Built CI/CD pipelines for controlled multi-environment deployments  
- Achieved zero-downtime deployments using Blue/Green strategy  
- Configured cross-region replication for database and storage  

---

##  Architecture Overview
This solution spans two AWS regions:

- **Primary Region:** `us-east-1`  
- **Secondary Region (Failover):** `us-west-1`  

Traffic is routed using DNS failover logic based on system health.

![Architecture](/screenshots/Architecture.jpeg)

---

##  System Design

### Traffic Flow

```
User → Route 53 (Health Check Routing)
↓
Primary Region (Active)
↓ (on failure)
Secondary Region (Failover)
```

---

### Core Infrastructure Components

#### Networking
- VPC deployed in both regions  
- Public and private subnets across multiple AZs  

#### Compute
- EC2 instances in Auto Scaling Groups  
- Application Load Balancer distributing traffic  

#### Database
- RDS PostgreSQL (Primary) in `us-east-1`  
- Cross-region read replica in `us-west-1`  

#### Storage
- S3 bucket in primary region  
- Cross-Region Replication (CRR) enabled  

#### CI/CD
- CodePipeline for orchestration  
- CodeBuild for build and packaging  
- CodeDeploy for blue/green deployments  

#### Monitoring & Notifications
- CloudWatch for health monitoring  
- SNS for alerting  

#### Configuration Management
- SSM Parameter Store for cross-region value sharing  

---

## Infrastructure as Code (IaC) – Multi-Region Disaster Recovery

This project uses **AWS CloudFormation** with **two nested master stacks**, each deployed in a different region:

- **Primary Region Stack** – Main production environment  
- **Secondary Region Stack** – Disaster recovery (DR) environment  

### Stack Structure

#### 1. Primary Region (Main Stack)
Controlled by a master stack, deploying:

```
NetworkStack                      SnsStack        CodeDeployStack    RolesStack             PrimaryBucketStack
     ↓                                |                  \
ComputeStack                          |                   \          CodebuildStack
     ↓ ---------------                |                    \               ↓
                      ↓              /                      \
AlbStackPrimary  DbStackPrimary     /                        \ ->  CodePipelineStackPrimary
     ↓                             /
MonitoringStack    <--------------/

## Key

- ↓ → ← dependency order  
- Same level - deployed in parallel  
```


#### 2. Secondary Region (DR Stack)
Controlled by another master stack, deploying:

```
NetworkStack      DbStackSecondary   CodeDeployStack    CodebuildStack         SecondaryBucketStack
     ↓                                    \                 |
ComputeStack                               \                |
     ↓                                      \               | 
                                             \              ↓
AlbStackSecondary                             \ ->  CodePipelineStackPrimary
     ↓                               
Route53Stack

## Key

- ↓ → ← dependency order  
- Same level - deployed in parallel 
```


### How the Stacks Connect

Both regions are **separate deployments**, but the secondary region depends on data from the primary region for replication and failover.

Data sharing and linkage are handled using:

- Stacks like AlbStackPrimary and DbStackPrimary stores outputs in Ssm parameters that will be later copied to secondary region to be used by some services i.e(Route53 and Rds read relica respectively) in the Secondary Region Stack 
- **Cross-region replication (S3, RDS)**  
- **Parameters** – Pass configuration values  
- **Outputs** – Provide resource identifiers (ARNs, endpoints)  

### Design Idea

Stacks are modular per region, but **DR resources depend on primary region data**.

### Result

- Clean structure  
- Easy to update  
- Scalable and reusable infrastructure  


---

##  CI/CD Architecture

### 1. Infrastructure Pipeline

Responsible for provisioning infrastructure across environments and regions.

**Workflow:**

```
CodePipeline → GitHub(Source) → CodeBuild(Build) → CloudFormation(Multi-Region)
```

**Capabilities:**

**Codepipeline**

- Integrates with services such as GitHub and CodeBuild
- Automatically triggers and executes workflows
- Uses manual approval gates to control promotion between stages
- Implements properly structured IAM permissions across services

**GitHub**

- Repository (Source)

**CodeBuild**

Mutiple Codebuild services are used for the different environments with their individual builspec.yml i.e `dev-buidspec.yml`, `staging-buildspec.yml`, and
`prod-buildspec.yml` respectively , their capabilities are : 

- Uploads all nested CloudFormation templates to an S3 bucket for stack referencing
- Deploys the primary region stack in `us-east-1`
- Retrieves critical resource values from AWS Systems Manager (SSM) Parameter Store in the primary region, i.e(primary DB's ARN, ALB's DNS name, ALB,s hostedzone ID ) and replicates the values into secondary region
- Deploys the secondary region stack in `us-west-1`
- Configures S3 cross-region replication on the primary bucket to using replication file 

- Deploys full infrastructure in both regions  
- Supports dev, staging, prod environments  
- Uses parameterized builds per environment  
- Includes manual approval gates  

**Cloudformation**

- Provisions main master stack's child stacks template resources across the two regions 

![Pipeline](/screenshots/Screenshot20.png)
Infrastructure Pipeline

---

### 2. CodeDeploy Pipeline

Handles deployment group creation and configuration.

**WorkFlow**
```
GitHub(Source) → CodeBuild(Build)
```

**Capabilities:**

**GitHub**

- Repository (Source)

**CodeBuild**

Mutiple Codebuild services are used for the different environments with their individual builspec.yml i.e `dev-codedeploy-buidspec.yml`, `staging-codedeploy-buildspec.yml`, and `prod-codedeploy-buildspec.yml` respectively , their capabilities are : 

- Overcomes CloudFormation limitations for deployment groups  
- Ensures consistent blue/green deployment configuration across regions  

![Pipeline](/screenshots/Screenshot21.png)

---

### 3. Application Pipelines

Dedicated pipelines per environment handling application delivery.

**Workflow:**

```
GitHub(Source) → CodeBuild(Build) → CodeDeploy(Blue/Green)(Deploy)
```

**Capabilities:**

**GitHub**

- Repository (Source)

**CodeBuild** via `builspec.yml`

- Creates a fresh directory `build-output` and copies the entire file including appspec.yml file to the root of it 
- Sets build-output as the base directory for artifacts
- Includes all files and subdirectories within build-output as output artifacts

**CodeDeploy** via appspec.yml

- Defines deployment configuration for a Linux-based environment
- Copies all application files from app/ to /var/www/html on the target server
- Overwrites existing files to ensure the latest version is deployed
- Applies file permissions (644) and assigns ownership to root
- Executes lifecycle hooks to control deployment flow:
 - **BeforeInstall**: Backs up existing index.html to /var/www/html/backup with a timestamp if it exists
 - **AfterInstall**: Sets ownership to root:root, applies 644 permission to index.html, and ensures backup directory has 755 access
 - **ApplicationStart**: Installs httpd if missing, enables and restarts the service, and verifies it is running
 - **ValidateService**: Checks server availability with retries and validates that the new content is being served, failing if not

![Pipeline](/screenshots/Screenshot2.png)

### Detailed Flow

```
(GitHub)
        ↓
Infrastructure Pipeline (if infrastructure changes detected)
        ↓
CloudFormation Deployment in both Regions 
        ↓
CodeDeploy Pipeline 
        ↓
Creation of Deployment groups 
        ↓
Application Pipeline Triggered
        ↓
CodeBuild 
        ↓
Packages required files as artifacts
        ↓
CodeDeploy(Ec2 Blue/Green)
        ↓
Install + Configure Application (via appspec + scripts)
        ↓
Run Validation Tests
        ↓
ALB Traffic Shift (Blue → Green)
        ↓
Terminate Blue Fleet
        ↓
Deployment Complete (Zero Downtime)

```

---

##  Deployment Lifecycle

### Initial Provisioning 

Infrastructure Pipeline  
→ CloudFormation Deployment  
→ Resources Created 
→ A working Web Application routed via ALB

![Deployment](/screenshots/Screenshot18.png)
Cloudformation Deployment (Prod Environment)(Primary Region)

![Deployment](/screenshots/Screenshot19.png)
Cloudformation Deployment (Prod Environment)(secondary Region)

![Deployment](/screenshots/Screenshot23.png)
ALB showing properties including DNS name (prod environment)(Primary Region)

![Deployment](/screenshots/Screenshot24.png)
ALB showing properties including DNS name (prod environment)(Secondary Region)

![Deployment](/screenshots/Screenshot17.png)
Working web application (prod environment)(Primary Region)

![Deployment](/screenshots/Screenshot1.png)
Working web application (prod environment)(Secondary Region)

### Continous Delivery 

**Deployment Strategy: Blue/Green**

- **Platform:** EC2 + CodeDeploy  
- **Approach:** Immutable deployment  

1. Code is pushed to repository  
2. Pipeline is triggered  
3. Application is packaged via CodeBuild  
4. CodeDeploy provisions green environment  
5. Validation scripts executed  
6. Traffic shifted via ALB  
7. Old environment terminated  

**Outcome:**  
Zero downtime with safe rollback capability  

![Deployment](/screenshots/Screenshot3.png)
Instances before deployment (prod environment)(Primary Region)

![Deployment](/screenshots/Screenshot5.png)
Pipeline Release (prod environment)(Primary Region)

![Deployment](/screenshots/Screenshot4.png)
Codedeploy Deployment (prod environment)(Primary Region)

![Deployment](/screenshots/Screenshot6.png)
Terminated and newly created ec2 resources after deployment (prod environment)(Primary Region)

![Deployment](/screenshots/Screenshot7.png)
ALB serving Updated Web Application (prod environment)(Primary Region)


---

##  Disaster Recovery Strategy

- Active-Passive architecture  
- Route 53 health checks detect failures  
- Automatic DNS failover to secondary region  

**Failover Flow:**

```
Primary Failure → Health Check Fails → DNS Switch → Traffic to Secondary
```

![Deployment](/screenshots/Screenshot8.png)
Route53 showing Hosted zone records 

![Deployment](/screenshots/Screenshot9.png)
Route53 showing Health Checks

![Deployment](/screenshots/Screenshot10.png)
Domain Name serving Web Application from primary region (prod environment)

![Deployment](/screenshots/Screenshot12.png)
Ochestrated Health Check failure (prod environment)

![Deployment](/screenshots/Screenshot11.png)
Domain Name serving Web Application from secondary region (prod environment)

**Note:** To be able to showcase failover , the secondary region was left at the initial deployment and did not undergo continious delivery, therefore the region is serving old Web Application

---

##  Data Replication Strategy

### RDS Replication
- Primary DB in `us-east-1`  
- Read replica in `us-west-1`  

![Replication](/screenshots/Screenshot13.png)
Rds showing replication (prod environment)

### S3 Replication
- Cross-region replication enabled  
- Automatic object duplication  

![Deployment](/screenshots/Screenshot14.png)
S3 showing replication (prod environment)
---

##  Repository Structure
```
├── app/
├── ci/
├── cloudformation/
│ ├── infrastructure-pipeline/
│ ├── master/
│ └── stacks/
├── params/
└── s3-replication-file/
```

---

##  Automation

- Build and deployment logic defined in buildspecs 
- CodeDeploy lifecycle hooks managed via appspec
- Environment-specific parameter files ensure consistency  

---

##  Monitoring & Observability

- CloudWatch for ALB and system health  
- Route 53 health checks for failover decisions  
- SNS for alert notifications  
- Ec2 Instance Logs

![Monitoring](/screenshots/Screenshot15.png)
Cloudwatch Healthy Host Count alaram triggered

![Monitoring](/screenshots/Screenshot16.png)
Ec2 httpd logs
---

##  Security Implementation

- IAM roles with least privilege  
- Private subnet isolation for compute resources  
- Secure parameter storage via SSM  
- Controlled access via ALB  

---

##  DevOps Capabilities Demonstrated

- Multi-region system design  
- Disaster recovery implementation  
- Blue/Green deployment strategy  
- CI/CD pipeline automation  
- Infrastructure as Code (CloudFormation)  
- Cross-region data replication  

---

##  Challenges & Resolutions

- **Cross-region dependency management**  
  Solved using SSM Parameter Store for sharing values  

- **CodeDeploy limitations in CloudFormation**  
  Addressed by introducing a dedicated deployment pipeline  

- **Failover validation complexity**  
  Resolved through controlled health check testing  

---

## Conclusion

This project demonstrates the ability to design and implement resilient, production-grade systems with disaster recovery, automated deployments, and multi-region fault tolerance. It reflects strong DevOps engineering practices focused on reliability, scalability, and automation.
