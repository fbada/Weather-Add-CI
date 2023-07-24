provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "allow_http_ssh" {
  name        = "sec group for weather-app"
  description = "Allow http inbound traffic"
  vpc_id      = "vpc-012e558b4d7dc12db" // replace with your actual VPC ID

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_ssh"
  }
}

resource "aws_instance" "webserver" {
  ami                    = "ami-04823729c75214919"
  instance_type          = "t2.micro"
  key_name               = "gl-key"
  vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]
  subnet_id              = "subnet-0962bf633da160d77" // replace this with your subnet ID

  user_data = <<-EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install -y docker
  sudo service docker start
  sudo usermod -a -G docker ec2-user
  sudo chkconfig docker on
  sudo docker run -d -p 3000:80 adafetic/weather-app

  EOF

  tags = {
    Name = "weather-app-instance"
  }
}

output "webserver-ip" {
  value = aws_instance.webserver.public_ip
}

output "url" {
  value = "http://${aws_instance.webserver.public_ip}:3000"
}
  

terraform {
  backend "s3" {
    bucket = "my-terraform-state002"
    key    = "gl-key"
    region = "us-east-1"
  }
}
