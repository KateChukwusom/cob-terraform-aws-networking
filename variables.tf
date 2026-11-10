#The name of the team
variable "team" {
  type        = string
  description = "The team that owns the network, used in resource names and tags"
  validation {
    condition     = length(var.team) <= 20
    error_message = "team must be 20 characters or fewer"
  }
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.team))
    error_message = "team must be lowercase letters, digits or hyphens only (ECR repository names must be lowercase)"
  }
}

#Deployment environment
variable "environment" {
  type        = string
  description = "Current environment"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod, it must be spelt that way"
  }
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the VPC"
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, e.g. 10.0.0.0/16"
  }
}

# Public subnets, keyed by a name you choose. This is what it should look like:

# public_subnets = {
#   public-a = { cidr_block = "10.0.1.0/24", availability_zone = "us-east-1a" }
#   public-b = { cidr_block = "10.0.2.0/24", availability_zone = "us-east-1b" }
# }
variable "public_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  description = "Public subnets keyed by name. Each gets a route to the internet gateway"
  default     = {}
  validation {
    condition     = alltrue([for k, s in var.public_subnets : can(cidrhost(s.cidr_block, 0))])
    error_message = "Every public subnet must have a valid cidr_block."
  }
}

# Private subnets, same shape as public_subnets
variable "private_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  description = "Private subnets keyed by name. They reach the internet through a NAT gateway if one is enabled"
  default     = {}
  validation {
    condition     = alltrue([for k, s in var.private_subnets : can(cidrhost(s.cidr_block, 0))])
    error_message = "Every private subnet must have a valid cidr_block."
  }
}

# The public subnet keys that should host a NAT gateway.
# [] = no NAT (private subnets have no internet access), one key = a single shared NAT (cheaper),
# one key per AZ = a NAT per AZ (highly available).
variable "nat_gateway_subnet_keys" {
  type        = list(string)
  description = "Keys of public_subnets that should each host a NAT gateway"
  default     = []
  validation {
    condition     = alltrue([for k in var.nat_gateway_subnet_keys : contains(keys(var.public_subnets), k)])
    error_message = "Every entry in nat_gateway_subnet_keys must be a key defined in public_subnets."
  }
  validation {
    condition     = length(var.nat_gateway_subnet_keys) == length(toset(var.nat_gateway_subnet_keys))
    error_message = "nat_gateway_subnet_keys must not have duplicates."
  }
  validation {
    condition = (
      length(distinct([for k in var.nat_gateway_subnet_keys : try(var.public_subnets[k].availability_zone, k)]))
      == length(var.nat_gateway_subnet_keys)
    )
    error_message = "nat_gateway_subnet_keys can hold at most one public subnet per availability zone."
  }
}