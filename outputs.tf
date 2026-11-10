# outputs.tf

output "vpc_id" {
  description = "ID of the VPC created"
  value       = aws_vpc.cob_vpc.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC created"
  value       = aws_vpc.cob_vpc.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, keyed by subnet name"
  value       = { for key, subnet in aws_subnet.cob_public_subnets : key => subnet.id }
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, keyed by subnet name"
  value       = { for key, subnet in aws_subnet.cob_private_subnets : key => subnet.id }
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways, keyed by the public subnet they sit in"
  value       = { for key, nat in aws_nat_gateway.cob_nat : key => nat.id }
}

output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = aws_internet_gateway.cob_igw.id
}

output "public_route_table_id" {
  description = "ID of the route table shared by every public subnet"
  value       = aws_route_table.cob_public_rt.id
}

output "private_route_table_ids" {
  description = "IDs of the private route tables, keyed by subnet name"
  value       = { for key, rt in aws_route_table.cob_private_rt : key => rt.id }
}