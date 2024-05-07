variable "vpc_id" {
  type        = string
  description = "VPC's ID"
}

variable "sg_name" {
  type        = string
  description = "Name of Security Group"
}

variable "sg_description" {
  type        = string
  description = "Description of Security Group"
}

variable "ingress_rules" {
  type = list(object({
    description     = string
    port            = number
    protocol        = string
    cidr_blocks     = optional(list(string), [])
    security_groups = optional(list(string), [])
  }))
  description = "Description of Security Group"
}