provider "aws" {
  region     = "us-east-1"
  access_key = 
  secret_key = 
}

#Criando VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

#Criando internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
  
}

#Criando tabela customizada de rota
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  
  tags = {
    Name = "Prod"
  }
}

#criando subnet

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "prod-subnet"
  }
}

#Associando subnet com a tabela de rota

resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Criando Security Group para permitir as portas 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
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
    Name = "allow_web"
  }
}


#criando network interface com o ip da subnet etapa 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id = aws_subnet.subnet-1.id
  private_ips = [ "10.0.1.50" ]
  security_groups = [ aws_security_group.allow_web.id ]
  
}  

#assinando o endere??o elastico de IP na network interface criada na etapa 7
#o aws_eip depende da implanta????o do gateway da internet, se tentar criala e ligar a um vpc que n??o tenha
#um gateway, vai gerar um erro, para ter um IP publico precisa ter um gateway
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]

}

#criando ubuntu server e instalando e habilitando apache2

resource "aws_instance" "web-server-instance" {
  ami = "ami-00874d747dde814fa"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "trf-access-key"
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  
  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'subindo instancia aws pelo terraform (manda a pizza) > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web-server"
  }
  
}
