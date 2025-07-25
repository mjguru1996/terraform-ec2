variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "ami_id" {
  type    = string
  default = "ami-0f918f7e67a3323f0" # Amazon Linux 2 (check region)
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}
