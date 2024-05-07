variable "vpc_name" {
  type        = string
  description = "VPC's name"
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR block for VPC should have prefix be 16 (16)"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability Zones (AZs)"

}

variable "number_public_subnets" {
  type        = number
  description = "Number of Public Subnets per AZ"

}

variable "number_private_subnets" {
  type        = number
  description = "Number of Private Subnets per AZ"

}

variable "nat_gateway" {
  type        = bool
  description = "Whether create Nat Gateway"
}

variable "s3_gateway" {
  type        = bool
  description = "Whether create S3 Gateway Endpoint"

}

variable "transit_gateway_id" {
  type        = string
  description = "Transit Gateway's ID"
}

variable "cidr_of_other_vpcs" {
  type        = list(string)
  description = "VPC2's CIDR"
}