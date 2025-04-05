# K8SLab
This project aims to facilitate the creation of simple Kubernetes cluster in AWS for learning purposes. Create the cluster as needed and subsequently destroy it. This allows you to avoid incurring costs for cloud resources during periods when the cluster is not in use. 


## Prerequisite
You should have AWS account created. Install and configure the AWS CLI. OpenToFu and Ansible are also necessary.

## How to create simple K8S lab
Clone the repository 

```
git clone https://github.com/mgospodinov-mg/k8slab.git
```

### Run OpenTofu 

By default the aws region is "us-west-2", the instance type is "t2.large" and the number of worker nodes is "1". Of course you may change them when you run the tofu command.

```
tofu plan
tofu apply
```
If you want to modify the variables

```
tofu apply -var="aws_region="us-east-1" -var="instance_type=t2.medium" -var="number_workers=2"
```

OpenTofu will generate an SSH key for accessing EC2 instances; this key will be located in the sshkeys directory.

### Run Ansible

The Ansible inventory file is automatically populated with the correct IP addresses. No need to change anything else.
Navigate to the ansible directory "<path>/ansible_k8slab" and execute the command below. 

```
ansible-playbook -i inventory.ini playbooks/k8slab-playbook.yaml -v
```

By default the playbook will install Kubernetes 1.30.1

To install a different Kubernetes version, modify the variables within the variables.yaml file.

### Connect to the Kuberntes cluster

Connect to the control plane using ssh. Go to the <path>/opentofu_k8slab/sshkeys directory

```
ssh -i <sshkey> ubuntu@<control plane public ip>
```

```
kubectl get nodes
```

Note: There is kubectl autocomplete installed and configured. 

