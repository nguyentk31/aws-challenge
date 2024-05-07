# VPC 
output "vpc_id" {
  value       = aws_vpc.uit.id
  description = "VPC id"
}

# Public subnets
output "public_subnets_id" {
  value       = aws_subnet.publics[*].id
  description = "Public subnets id"
}

# Private subnets
output "private_subnets_id" {
  value       = aws_subnet.privates[*].id
  description = "Private subnets id"
}

output "private_subnets_cidr" {
  value       = aws_subnet.privates[*].cidr_block
  description = "Private subnets id"
}