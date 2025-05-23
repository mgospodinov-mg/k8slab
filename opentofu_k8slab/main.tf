provider "aws" {
    region = var.aws_region
}

resource "aws_vpc" "k8slab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "k8slab_vpc"
  }
}

# Retrieve Availability Zones within a Specified Region
data "aws_availability_zones" "region_azones" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_ec2_instance_type_offerings" "k8s_instance_type" {
  for_each = toset(data.aws_availability_zones.region_azones.names)
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
  filter {
    name   = "location"
    values = [each.key]
  }
  location_type = "availability-zone"
}

locals {
  azones_instances = keys({
    for az, details in data.aws_ec2_instance_type_offerings.k8s_instance_type: 
    az => details.instance_types if length(details.instance_types) != 0 })
}

resource "random_shuffle" "az" {
  input        = local.azones_instances
  result_count = 1
}

resource "aws_subnet" "k8slab_subnet" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.k8slab_vpc.id
  availability_zone = random_shuffle.az.result[0]
}

resource "aws_internet_gateway" "k8slab_gw" {
  vpc_id = aws_vpc.k8slab_vpc.id
}

resource "aws_route_table" "k8slab_rt" {
 vpc_id = aws_vpc.k8slab_vpc.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.k8slab_gw.id
 }
 
 tags = {
   Name = "k8slab Route Table"
 }
}

resource "aws_route_table_association" "k8slab_association" {
  subnet_id      = aws_subnet.k8slab_subnet.id
  route_table_id = aws_route_table.k8slab_rt.id
}

resource "aws_security_group" "k8slab_security" {
  name        = "allow-all"
  vpc_id      = aws_vpc.k8slab_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_all_port" {
  security_group_id = aws_security_group.k8slab_security.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.k8slab_security.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" 
}

resource "tls_private_key" "generated_sshkey" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "k8slab_private_key"{
  filename = pathexpand("./sshkeys/k8slab")
  file_permission = "600"
  content = tls_private_key.generated_sshkey.private_key_openssh
}

resource "aws_key_pair" "k8slab_sshkey" {
  key_name   = "k8slab_sshkey"
  public_key = tls_private_key.generated_sshkey.public_key_openssh
}

data "aws_ami" "ubuntu2404" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "master" {
  ami           = data.aws_ami.ubuntu2404.id
  instance_type = var.instance_type
  subnet_id =  aws_subnet.k8slab_subnet.id
  vpc_security_group_ids = [aws_security_group.k8slab_security.id]
  key_name = aws_key_pair.k8slab_sshkey.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
  }  
  
  tags = {
    Name = "Master node"
  }
}

resource "aws_instance" "worker" {
  count = var.number_workers
  ami           = data.aws_ami.ubuntu2404.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.k8slab_subnet.id
  vpc_security_group_ids = [aws_security_group.k8slab_security.id]
  key_name = aws_key_pair.k8slab_sshkey.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
  }  

  tags = {
    Name = "Worker${count.index + 1} node"
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("./templates/inventory.tftpl",
    {
      master_ip = aws_instance.master.public_ip
      worker_ip = aws_instance.worker.*.public_ip
    }
  )
  filename = "../ansible_k8slab/inventory.ini"
}
