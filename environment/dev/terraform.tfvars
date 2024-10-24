project_name = "aws-ecs-cluster"

region = "us-east-1"


##### SSM VPC Parameters ##### 

ssm_vpc_id = "/aws-vpc/vpc/vpc_id"

ssm_public_subnet_1 = "/aws-vpc/vpc/subnet_public_1a"

ssm_public_subnet_2 = "/aws-vpc/vpc/subnet_public_1b"

ssm_public_subnet_3 = "/aws-vpc/vpc/subnet_public_1c"

ssm_private_subnet_1 = "/aws-vpc/vpc/subnet_private_1a"

ssm_private_subnet_2 = "/aws-vpc/vpc/subnet_private_1b"

ssm_private_subnet_3 = "/aws-vpc/vpc/subnet_private_1c"


##### Balancer #####

load_balancer_internal = false

load_balancer_type = "application"


#### ECS General ######

nodes_ami = "ami-0dc67873410203528"

node_instance_type = "c6a.large"

node_volume_size = "50"

node_volume_type = "gp3"

cluster_on_demand_min_size = 2