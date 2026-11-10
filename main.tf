locals {
  # This is the base combination, reused everywhere
  team_environment = "${var.team}-${var.environment}"

  # tags applied to resource blocks that allows tags argument
  resource_tags = {
    Team        = var.team
    Environment = var.environment
  }

  # NAT gateways are only created when at least one public subnet key is listed in nat_gateway_subnet_keys
  nat_enabled = length(var.nat_gateway_subnet_keys) > 0

  # Maps an availability zone to the public subnet key that hosts a NAT gateway in that zone,
  # this is how a private subnet finds a NAT gateway in its own AZ
  nat_subnet_key_by_az = {
    for key in var.nat_gateway_subnet_keys :
    var.public_subnets[key].availability_zone => key
  }

  # Private subnets in an AZ without a NAT gateway fall back to the first NAT gateway listed
  fallback_nat_key = local.nat_enabled ? var.nat_gateway_subnet_keys[0] : null
}

#This creates the VPC
resource "aws_vpc" "cob_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.resource_tags, { Name = "${local.team_environment}-vpc" })
}

#This creates the internet gateway that gives the public subnets a route to the internet
resource "aws_internet_gateway" "cob_igw" {
  vpc_id = aws_vpc.cob_vpc.id

  tags = merge(local.resource_tags, { Name = "${local.team_environment}-igw" })
}

#This creates the public subnets, as many as needed, the for_each argument loops over the map and creates each one
resource "aws_subnet" "cob_public_subnets" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.cob_vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.resource_tags, {
    Name = "${local.team_environment}-${each.key}"
    Tier = "public"
  })
}

#This creates the private subnets
resource "aws_subnet" "cob_private_subnets" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.cob_vpc.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = merge(local.resource_tags, {
    Name = "${local.team_environment}-${each.key}"
    Tier = "private"
  })
}

#This creates one elastic IP per NAT gateway
resource "aws_eip" "cob_nat_eip" {
  for_each = toset(var.nat_gateway_subnet_keys)

  domain = "vpc"

  tags = merge(local.resource_tags, { Name = "${local.team_environment}-nat-eip-${each.key}" })
}

#This creates the NAT gateways, each one sits inside the public subnet named in nat_gateway_subnet_keys
resource "aws_nat_gateway" "cob_nat" {
  for_each = toset(var.nat_gateway_subnet_keys)

  allocation_id = aws_eip.cob_nat_eip[each.key].id
  subnet_id     = aws_subnet.cob_public_subnets[each.key].id

  tags = merge(local.resource_tags, { Name = "${local.team_environment}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.cob_igw]
}

#This creates a single route table shared by every public subnet
resource "aws_route_table" "cob_public_rt" {
  vpc_id = aws_vpc.cob_vpc.id

  tags = merge(local.resource_tags, { Name = "${local.team_environment}-public-rt" })
}

#This sends all outbound public traffic to the internet gateway
resource "aws_route" "cob_public_internet" {
  route_table_id         = aws_route_table.cob_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cob_igw.id
}

#This associates every public subnet with the public route table
resource "aws_route_table_association" "cob_public_assoc" {
  for_each = aws_subnet.cob_public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.cob_public_rt.id
}

#This creates a route table per private subnet, so each one can point at the NAT gateway in its own AZ
resource "aws_route_table" "cob_private_rt" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.cob_vpc.id

  tags = merge(local.resource_tags, { Name = "${local.team_environment}-${each.key}-rt" })
}

#This sends outbound private traffic through a NAT gateway, only created when NAT gateways exist
resource "aws_route" "cob_private_nat" {
  for_each = local.nat_enabled ? var.private_subnets : {}

  route_table_id         = aws_route_table.cob_private_rt[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.cob_nat[lookup(local.nat_subnet_key_by_az, each.value.availability_zone, local.fallback_nat_key)].id
}

#This associates every private subnet with its own route table
resource "aws_route_table_association" "cob_private_assoc" {
  for_each = aws_subnet.cob_private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.cob_private_rt[each.key].id
}