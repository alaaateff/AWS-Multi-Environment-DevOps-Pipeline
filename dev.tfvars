region = "us-east-1"
ami = "ami-0236922087fa98b6e"
cidr block vpc = "10.10.0.0/16"
public subnets = {
   a = "10.10.1.0/24"
   b = "10.10.2.0/24"
}

private subnets = {
   a = "10.10.3.0/24"
   b = "10.10.4.0/24"
}