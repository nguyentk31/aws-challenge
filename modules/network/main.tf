# VPC
resource "aws_vpc" "uit" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

# Subnet expand network bit by 8 (like from /16 to /24)
# Public Subnets
resource "aws_subnet" "publics" {
  count                   = var.number_public_subnets
  vpc_id                  = aws_vpc.uit.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "privates" {
  count             = var.number_private_subnets
  vpc_id            = aws_vpc.uit.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + (var.number_public_subnets))
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.vpc_name}-private-${count.index + 1}"
  }
}

# Internet gateway, elastic ip and attach to nat gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.uit.id

  tags = {
    Name = "${var.vpc_name}-internetgw"
  }
}

resource "aws_eip" "natgw-eip" {
  count      = var.nat_gateway ? 1 : 0
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.vpc_name}-elasticIP"
  }
}

resource "aws_nat_gateway" "natgw" {
  count         = var.nat_gateway ? 1 : 0
  allocation_id = aws_eip.natgw-eip[0].id
  subnet_id     = aws_subnet.publics[0].id // The first public subnet

  tags = {
    Name = "${var.vpc_name}-natgw"
  }
}

# Transit gateway and VPC attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "uit" {
  count              = length(var.cidr_of_other_vpcs)>0 ? 1 : 0
  subnet_ids         = aws_subnet.privates[*].id
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.uit.id

  tags = {
    Name = "${var.vpc_name}-transitgw-attachment"
  }
}

# Route tables and associations
# Public route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.uit.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  dynamic "route" {
    for_each = var.cidr_of_other_vpcs
    content {
      cidr_block         = route.value
      transit_gateway_id = var.transit_gateway_id
    }
  }

  tags = {
    Name = "${var.vpc_name}-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.publics)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.publics[count.index].id
}

# Private route tables
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.uit.id

  dynamic "route" {
    for_each = var.nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.natgw[0].id
    }
  }

  dynamic "route" {
    for_each = var.cidr_of_other_vpcs
    content {
      cidr_block         = route.value
      transit_gateway_id = var.transit_gateway_id
    }
  }

  tags = {
    Name = "${var.vpc_name}-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.privates)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.privates[count.index].id
}

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "vpc2_endpoint" {
  vpc_id       = aws_vpc.uit.id
  service_name = "com.amazonaws.us-east-1.s3"

  tags = {
    Name = "${var.vpc_name}-endpointgw"
  }
}

