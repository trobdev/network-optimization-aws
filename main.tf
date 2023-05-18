# --- root/main.tf ---

resource "aws_vpc" "main" {
    count = var.vpc_count
    cidr_block = "10.0.${count.index}.0/24"
    tags = {
        Name = "main-vpc-${count.index}"
    }
}

resource "aws_subnet" "subnet" {
    count = var.vpc_count * length(var.azs)
    vpc_id = aws_vpc.main[floor(count.index / length(var.azs))].id
    cidr_block = "10.0.${floor(count.index / length(var.azs))}.${floor(count.index % length(var.azs)) * 16}/28"
    availability_zone = var.azs[count.index % length(var.azs)]
    tags = {
        Name = "subnet-${count.index}"
    }
}

resource "aws_ec2_transit_gateway" "transit_gateway" {
    description = "main transit gateway"
    tags = {
        Name = "tgw-main"
    }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_vpc_attachment" {
    count = var.vpc_count
    transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    vpc_id = aws_vpc.main[count.index].id
    subnet_ids = [
        aws_subnet.subnet[count.index * length(var.azs)].id,
        aws_subnet.subnet[count.index * length(var.azs) + 1].id
    ]

    tags = {
        Name = "tgw-attachment-${count.index}"
    }
}

resource "aws_route_table" "route_table" {
    count = var.vpc_count
    vpc_id = aws_vpc.main[count.index].id

    route {
        cidr_block = "0.0.0.0/0"
        transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
    }

    tags = {
        Name = "rt-${count.index}"
    }
}