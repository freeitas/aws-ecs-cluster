## Architecture decisions

### Why EC2 capacity providers and not Fargate here

I run this cluster on `c6a.large` nodes behind two ASG-backed capacity providers because I want packing density: many small tasks sharing one billed host, with the node's spare headroom absorbing bursts instead of being re-billed per task. Fargate would delete `launch_template.tf`, `templates/user-data.tpl` and `iam_instance_profile.tf` — and with them the AMI choice, the 50 GiB gp3 root volume and the `ECS_CLUSTER` line that registers each node. Fargate Spot exists, but it is priced and reclaimed per task, not per node — a different trade from `asg_spots.tf`.

### Spot capacity is registered, but never the default

`ecs.tf` attaches both capacity providers to the cluster, yet `default_capacity_provider_strategy` names only on-demand, at weight 100 / base 0. Spot nodes exist and a service has to ask for them by name. I rejected a mixed default strategy (base on-demand + weighted spot): with it, every service deployed here — including ones that cannot drain inside the two-minute interruption notice — silently lands on reclaimable capacity, and the failure only surfaces the first time AWS takes a node back. The `max_price = "0.30"` ceiling in `launch_template_spots.tf` sits well above the `c6a.large` on-demand rate on purpose: interruptions should come from capacity reclaim, never from being outbid.

### ECS managed scaling moves `desired_capacity`, not my plans

Terraform seeds `desired_capacity` on both ASGs and then stops looking: each carries `ignore_changes = [desired_capacity]`, and each capacity provider runs managed scaling at `target_capacity = 90`. Terraform keeps floor and ceiling; the ECS scaler picks the number between them. The alternative — leaving `desired_capacity` under Terraform's control, or attaching a CPU target-tracking policy — means every `plan` reports drift against whatever the scaler did minutes earlier, and an apply terminates instances out from under placed tasks.

### SSM Parameter Store as the cross-stack contract, not remote state

`data.tf` reads the VPC and all six subnet ids from `/aws-vpc/vpc/*`; `parameters.tf` writes the ALB ARN and listener ARN back under `/aws/ecs/lb/`. Consumers read two strings by name. With `terraform_remote_state` instead, every service stack would need read access to the whole state object in `aws-containers-statefiles` — every attribute of every resource here — and any rename would break their plan.

### One shared ALB lives with the cluster, not with the services

`load_balancer.tf` creates the ALB and an HTTP :80 listener whose default action is a fixed 200 response: a deliberate placeholder, so service stacks attach their own target groups and rules to the listener ARN published in SSM. An ALB per service would mean a separate hourly floor and DNS name each. What I accept in exchange: services share one listener-rule priority space, and destroying this stack takes every service's ingress with it.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.43.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.on_demand](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_group.spots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_ecs_capacity_provider.on_demand](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider) | resource |
| [aws_ecs_capacity_provider.spots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider) | resource |
| [aws_ecs_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_launch_template.on_demand](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_launch_template.spots](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_security_group.lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.ingress_443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ingress_80](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.subnet_ranges](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ssm_parameter.lb_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.subnet_private_1a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.subnet_private_1b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.subnet_private_1c](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.subnet_public_1a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.subnet_public_1b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.subnet_public_1c](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_on_demand_desired_size"></a> [cluster\_on\_demand\_desired\_size](#input\_cluster\_on\_demand\_desired\_size) | The desired number of on-demand instances in the ECS cluster. | `number` | n/a | yes |
| <a name="input_cluster_on_demand_max_size"></a> [cluster\_on\_demand\_max\_size](#input\_cluster\_on\_demand\_max\_size) | The maximum size of the ECS cluster for on-demand instances. | `number` | n/a | yes |
| <a name="input_cluster_on_demand_min_size"></a> [cluster\_on\_demand\_min\_size](#input\_cluster\_on\_demand\_min\_size) | The minimum size of the ECS cluster for on-demand instances. | `number` | n/a | yes |
| <a name="input_cluster_spot_desired_size"></a> [cluster\_spot\_desired\_size](#input\_cluster\_spot\_desired\_size) | The desired number of spot instances in the ECS cluster. | `number` | n/a | yes |
| <a name="input_cluster_spot_max_size"></a> [cluster\_spot\_max\_size](#input\_cluster\_spot\_max\_size) | The maximum size of the ECS cluster for spot instances. | `number` | n/a | yes |
| <a name="input_cluster_spot_min_size"></a> [cluster\_spot\_min\_size](#input\_cluster\_spot\_min\_size) | The minimum size of the ECS cluster for spot instances. | `number` | n/a | yes |
| <a name="input_load_balancer_internal"></a> [load\_balancer\_internal](#input\_load\_balancer\_internal) | Defines whether the Load Balancer should be internal (true) or external (false). | `bool` | n/a | yes |
| <a name="input_load_balancer_type"></a> [load\_balancer\_type](#input\_load\_balancer\_type) | The type of Load Balancer to be created (e.g., 'application' or 'network'). | `string` | n/a | yes |
| <a name="input_node_instance_type"></a> [node\_instance\_type](#input\_node\_instance\_type) | The EC2 instance type to be used by the ECS nodes. | `string` | n/a | yes |
| <a name="input_node_volume_size"></a> [node\_volume\_size](#input\_node\_volume\_size) | The volume size, in GiB, to be used by the ECS nodes. | `number` | n/a | yes |
| <a name="input_node_volume_type"></a> [node\_volume\_type](#input\_node\_volume\_type) | The EBS volume type to be used by the ECS nodes (e.g., 'gp2', 'io1'). | `string` | n/a | yes |
| <a name="input_nodes_ami"></a> [nodes\_ami](#input\_nodes\_ami) | The AMI to be used by the ECS cluster nodes. | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The project name, used for naming resources within the scope of this Terraform configuration. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region where resources will be created. | `string` | n/a | yes |
| <a name="input_ssm_private_subnet_1"></a> [ssm\_private\_subnet\_1](#input\_ssm\_private\_subnet\_1) | The ID of the first private subnet in the VPC for SSM resources. | `string` | n/a | yes |
| <a name="input_ssm_private_subnet_2"></a> [ssm\_private\_subnet\_2](#input\_ssm\_private\_subnet\_2) | The ID of the second private subnet in the VPC for SSM resources. | `string` | n/a | yes |
| <a name="input_ssm_private_subnet_3"></a> [ssm\_private\_subnet\_3](#input\_ssm\_private\_subnet\_3) | The ID of the third private subnet in the VPC for SSM resources. | `string` | n/a | yes |
| <a name="input_ssm_public_subnet_1"></a> [ssm\_public\_subnet\_1](#input\_ssm\_public\_subnet\_1) | The ID of the first public subnet in the VPC for SSM resources. | `string` | n/a | yes |
| <a name="input_ssm_public_subnet_2"></a> [ssm\_public\_subnet\_2](#input\_ssm\_public\_subnet\_2) | The ID of the second public subnet in the VPC for SSM resources. | `string` | n/a | yes |
| <a name="input_ssm_public_subnet_3"></a> [ssm\_public\_subnet\_3](#input\_ssm\_public\_subnet\_3) | The ID of the third public subnet in the VPC for SSM resources. | `string` | n/a | yes |
| <a name="input_ssm_vpc_id"></a> [ssm\_vpc\_id](#input\_ssm\_vpc\_id) | The VPC ID where SSM-related resources will be created. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lb_ssm_arn"></a> [lb\_ssm\_arn](#output\_lb\_ssm\_arn) | The Amazon Resource Name (ARN) of the AWS Systems Manager (SSM) parameter that stores the Load Balancer ARN. This value can be used to reference the Load Balancer ARN in IAM policies, security rules, or anywhere else that requires the Load Balancer ARN. |
| <a name="output_lb_ssm_listener"></a> [lb\_ssm\_listener](#output\_lb\_ssm\_listener) | The ID of the AWS Systems Manager (SSM) parameter that stores the Load Balancer Listener. This value can be used to reference the Listener in automation, scripts, or within other AWS configurations that require the Listener ID. |
| <a name="output_load_balancer_dns"></a> [load\_balancer\_dns](#output\_load\_balancer\_dns) | The DNS name of the created Load Balancer. This value can be used to access the Load Balancer within the network or from the internet, depending on the configuration. |
<!-- END_TF_DOCS -->
