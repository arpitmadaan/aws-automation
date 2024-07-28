# This repository has terraform code to create Backup Plans, Backup Rules, Backup Vault, IAM Role and Resource Assignment for backing up Ec2 instances and volumes attached to it on AWS. The list of instance names has to be given in instances.tfvars file
## Steps to Automate Terraform with Jenkins
### 1: Setup Jenkins and Terraform on Your Jenkins Server
### Ensure Jenkins is installed and configured with the necessary plugins, including the Terraform plugin. Also, ensure Terraform is installed on the Jenkins server.

### 2: Create a Jenkins Pipeline Job
### Create a new pipeline job in Jenkins to manage your Terraform configurations.

### 3: Store Your Terraform Code in a Version Control System (e.g., GitHub)
### Store your Terraform code in a repository, and make sure Jenkins has access to this repository.

### 4: Create a Jenkinsfile for Your Pipeline
### Create a Jenkinsfile in the root of your Terraform repository. This file will define the steps Jenkins should take to apply your Terraform configuration.

## Configure Jenkins Job
### Source Code Management: Configure the repository URL and credentials if necessary.
### Build Triggers: Set up triggers to monitor changes in your repository. For example:
#### 1: Poll SCM: Poll the repository at regular intervals (e.g., every 5 minutes).
#### 2: Webhook: Set up a webhook in GitHub to trigger Jenkins on each push.