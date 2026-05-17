module "network" {
    source = "./modules/network"
    cidr_block_vpc = var.cidr_block_vpc
    pub_cidr = var.pub_cidr
    priv_cidr = var.priv_cidr
}

resource "aws_instance" "bastion" {
  ami                     = var.ami
  instance_type           = "t3.micro"
  subnet_id = module.network.public_subnet_id
  associate_public_ip_address  = true
   vpc_security_group_ids = [
    aws_security_group.allow_ssh.id
  ]
  provisioner "local-exec" {
    command = "echo The bastion\\'s IP address is ${self.public_ip}"
  }
}

resource "aws_instance" "application" {
  ami                     = var.ami
  instance_type           = "t3.micro"
  subnet_id = module.network.private_subnet_id
   vpc_security_group_ids = [
    aws_security_group.second_sg.id
  ]
}

resource "aws_security_group" "second_sg" {
  vpc_id = module.network.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [module.network.vpc_cidr]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [module.network.vpc_cidr]
  }
}

resource "aws_security_group" "allow_ssh" {
  vpc_id = module.network.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
