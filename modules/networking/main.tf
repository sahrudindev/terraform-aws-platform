# ============================================================================
# MODULE NETWORKING — VPC, subnet publik & privat, IGW, NAT, route table
# ============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name    = "${var.project}-${var.environment}"
  azs     = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  nat_qty = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.az_count) : 0

  # CIDR subnet diturunkan otomatis dari VPC CIDR
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

# --- Subnet publik (untuk ALB, NAT) ----------------------------------------
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch
  tags = {
    Name                     = "${local.name}-public-${count.index + 1}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1" # untuk EKS public load balancer
  }
}

# --- Subnet privat (untuk ECS, RDS, EKS nodes) -----------------------------
resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name                              = "${local.name}-private-${count.index + 1}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1" # untuk EKS internal load balancer
  }
}

# --- NAT Gateway (akses internet keluar dari subnet privat) -----------------
resource "aws_eip" "nat" {
  count  = local.nat_qty
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-eip-${count.index + 1}" }
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_qty
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${local.name}-nat-${count.index + 1}" }
  depends_on    = [aws_internet_gateway.this]
}

# --- Route table publik -----------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Route table privat (satu per-AZ; rute ke NAT bila ada) -----------------
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-private-rt-${count.index + 1}" }
}

resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? var.az_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # Jika single NAT, semua subnet privat lewat NAT yang sama (index 0)
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- Default security group -------------------------------------------------
#
# Every VPC ships with a default security group that allows all traffic between
# its members. Nothing here uses it, so it is explicitly emptied rather than
# left as a quiet way around the rules above.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # No ingress and no egress blocks: both are revoked.

  tags = { Name = "${local.name}-default-sg-locked" }
}
