region = "us-east-1"
ami = "ami-00b105a12aa2a60eb"
cidr block vpc = "10.30.0.0/16"
public subnets = {
   a = "10.30.1.0/24"
   b = "10.30.2.0/24"
}

private subnets = {
   a = "10.30.3.0/24"
   b = "10.30.4.0/24"
}