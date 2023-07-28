provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "web_server_sg_tf" {
  name        = "le-appliance-sg-tf"
  description = "Allow HTTPS to appliance"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  description       = "ssh ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_server_sg_tf.id
}

resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  description       = "https ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_server_sg_tf.id
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  description       = "appliance outbound"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_server_sg_tf.id
}

resource "aws_instance" "deb12" {
  ami           = "ami-051fed912770b13d5"
  instance_type = "t3.medium"
  key_name      = "cis-deb10-lvl1"
  #vpc_security_group_ids = [aws_security_group.web_server_sg_tf.id]
  tags = {
    Name        = "deb12"
    Description = "Debian 12"
  }

  root_block_device {
    volume_size = 80
  }
}
