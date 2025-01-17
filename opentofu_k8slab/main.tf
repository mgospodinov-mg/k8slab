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

resource "aws_subnet" "k8slab_subnet" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.k8slab_vpc.id
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
  name = "allow-all"

  vpc_id = aws_vpc.k8slab_vpc.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}      

resource "aws_key_pair" "k8slab_sshkey" {
  key_name   = "k8slab_sshkey"
  public_key = trimspace(file("./sshkeys/k8slab.pem"))
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
    Name = "Worker node"
  }
}



