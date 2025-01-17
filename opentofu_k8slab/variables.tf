variable "aws_region" {
    description = "The region in AWS"
    default = "us-west-2"
}

#A t2.large instance is well-suited for laboratory use, though a t2.medium instance would also be adequate.
variable "instance_type" {
    description = "AWS instance type"
    default = "t2.large"
}