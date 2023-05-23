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

resource "aws_route_table" "route_table_subnets" {
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

resource "aws_route_table_association" "route_table_association_subnets" { 
    count = length(aws_subnet.subnet)
    subnet_id = element(aws_subnet.subnet.*.id, count.index)
    route_table_id = element(aws_route_table.route_table_subnets.*.id, floor(count.index / length(var.azs)))
}
#---  FLOW LOGS ---
resource "aws_flow_log" "vpc_flow_log" {
  count         = var.vpc_count
  traffic_type  = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_log_group.arn
  vpc_id   = aws_vpc.main[count.index].id
  iam_role_arn  = aws_iam_role.flow_log_role.arn
}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  name              = "/aws/vpc/flow-log"
  retention_in_days = 30
}

resource "aws_iam_role" "flow_log_role" {
  name               = "flow-log-role"
  assume_role_policy = jsonencode({
    Version   : "2012-10-17",
    Statement : [
      {
        Action : "sts:AssumeRole",
        Effect : "Allow",
        Principal : {
          Service : [
            "vpc-flow-logs.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "flow_log_policy_attachment" {
  policy_arn   = aws_iam_policy.flow_log_policy.arn
  role         = aws_iam_role.flow_log_role.name
}

resource "aws_iam_policy" "flow_log_policy" {
  name   = "flow-log-policy"
  policy = jsonencode({
    Version   : "2012-10-17",
    Statement : [
      {
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        Effect   : "Allow",
        Resource : "*"
      }
    ]
  })
}