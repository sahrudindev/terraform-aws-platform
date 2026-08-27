# Runs entirely against a mocked AWS provider: no credentials, no API calls,
# no cost. `terraform test` in CI therefore needs nothing from AWS.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
    }
  }

  # Mocked data sources return arbitrary strings by default, which fails
  # validation for anything that must be real JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project     = "cloudops"
  environment = "test"
  vpc_cidr    = "10.99.0.0/16"
}

run "one_subnet_pair_per_availability_zone" {
  command = plan

  variables {
    az_count = 2
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Expected one public subnet per AZ."
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Expected one private subnet per AZ."
  }

  assert {
    condition     = length(aws_route_table.private) == 2
    error_message = "Each private subnet needs its own route table so NAT can differ per AZ."
  }
}

run "public_and_private_cidrs_never_overlap" {
  command = plan

  variables {
    az_count = 3
  }

  assert {
    condition = length(setintersection(
      [for s in aws_subnet.public : s.cidr_block],
      [for s in aws_subnet.private : s.cidr_block],
    )) == 0
    error_message = "Public and private subnet CIDRs overlap."
  }

  assert {
    condition     = length(distinct([for s in aws_subnet.public : s.cidr_block])) == 3
    error_message = "Public subnet CIDRs are not distinct."
  }
}

run "no_nat_gateway_when_disabled" {
  command = plan

  variables {
    az_count           = 2
    enable_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "NAT Gateway must not be created when disabled - it bills ~$32/month while idle."
  }

  assert {
    condition     = length(aws_eip.nat) == 0
    error_message = "No Elastic IP should be allocated when NAT is disabled."
  }
}

run "single_nat_gateway_shares_one_across_azs" {
  command = plan

  variables {
    az_count           = 2
    enable_nat_gateway = true
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway must produce exactly one NAT."
  }

  assert {
    condition     = length(aws_route.private_nat) == 2
    error_message = "Every private route table still needs a default route to the shared NAT."
  }
}

run "highly_available_nat_is_one_per_az" {
  command = plan

  variables {
    az_count           = 2
    enable_nat_gateway = true
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Expected one NAT Gateway per AZ when single_nat_gateway is false."
  }
}

run "dns_is_enabled_for_private_endpoints" {
  command = plan

  variables {
    az_count = 2
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames && aws_vpc.this.enable_dns_support
    error_message = "DNS hostnames and support are required by RDS and VPC endpoints."
  }
}
