# REUSABLE Networking Module

A reusable Terraform module that builds an AWS VPC with public and private subnets, an internet gateway, optional NAT gateways, and the route tables that tie them together, driven entirely by variables.

## Design principles

- **Nothing is hardcoded.** CIDRs, availability zones and subnet names all come in through variables.
- **Everything optional has an empty default.** No private subnets? No NAT? Leave them out and nothing is created.
- **`for_each` over one-off resources.** Subnets, NAT gateways and route tables are all built with `for_each` over maps, so going from 2 subnets to 6 only needs more data.
- **Validation catches mistakes before `apply`.** Bad CIDRs, uppercase team names, NAT keys that point to a non-existent public subnet and two NAT gateways in one AZ all fail at `plan`.

## Variables

| Variable | Type | Default | Description |
| --- | --- | --- | --- |
| `team` | string | required | Lowercase team name, used in names and tags (max 20 characters) |
| `environment` | string | required | `"dev"` or `"prod"` |
| `vpc_cidr` | string | `"10.0.0.0/16"` | VPC CIDR block, validated |
| `public_subnets` | map(object) | `{}` | Keyed by name, each with `cidr_block` and `availability_zone` |
| `private_subnets` | map(object) | `{}` | Same shape as `public_subnets` |
| `nat_gateway_subnet_keys` | list(string) | `[]` | Keys of `public_subnets` that should each host a NAT gateway (one per AZ at most) |

### Choosing a NAT strategy

| `nat_gateway_subnet_keys` | Result |
| --- | --- |
| `[]` | No NAT. Private subnets have no internet access |
| `["public-a"]` | One shared NAT (cheapest, fine for dev). Every private subnet routes through it |
| `["public-a", "public-b"]` | One NAT per AZ (highly available). Each private subnet uses the NAT in its own AZ |

```hcl
public_subnets = {
  public-a = { cidr_block = "10.0.1.0/24", availability_zone = "us-east-1a" }
  public-b = { cidr_block = "10.0.2.0/24", availability_zone = "us-east-1b" }
}
```

## Outputs

| Output | Description |
| --- | --- |
| `vpc_id` | ID of the VPC |
| `vpc_cidr` | CIDR of the VPC |
| `public_subnet_ids` | Map of subnet name, subnet ID |
| `private_subnet_ids` | Map of subnet name, subnet ID |
| `nat_gateway_ids` | Map of public subnet key, NAT gateway ID |
| `internet_gateway_id` | ID of the internet gateway |
| `public_route_table_id` | ID of the shared public route table |
| `private_route_table_ids` | Map of subnet name, private route table ID |

## Using this module

```hcl
module "networking" {
  source = "git::https://github.com/KateChukwusom/AWSTerraform_Modules.git//modules/Networking?ref=v1.0.0"

  team                    = "platform"
  environment             = "dev"
  public_subnets          = var.public_subnets
  private_subnets         = var.private_subnets
  nat_gateway_subnet_keys = ["public-a"]
}
```

## Requirements

Terraform >= 1.9.0 (validation blocks reference other variables) and the AWS provider ~> 6.0.
