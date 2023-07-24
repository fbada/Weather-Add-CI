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

resource "aws_lb" "weather_app_lb" {
  name               = "your_load_balancer_name"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http_ssh.id]
  subnets            = ["subnet-0962bf633da160d77"]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.weather_app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_lb_target_group" "example" {
  name     = "tf-example"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = "vpc-012e558b4d7dc12db"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_lb.weather_app_lb.dns_name
    origin_id   = "your_cloudfront_distribution_name"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "your_cloudfront_distribution_name"

    forwarded_values {
      query_string = false
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "your_certificate_arn"
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  is_ipv6_enabled = true
}

output "webserver-ip" {
  value = aws_instance.webserver.public_ip
}

output "url" {
  value = "http://${aws_instance.webserver.public_ip}:3000"
}

output "load_balancer_dns_name" {
  value = aws_lb.weather_app_lb.dns_name
}

output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

terraform {
  backend "s3" {
    bucket = "my-terraform-state002"
    key    = "gl-key"
    region = "us-east-1"
  }
}
