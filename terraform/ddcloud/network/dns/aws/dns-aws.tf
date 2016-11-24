########
# Inputs
########

# The name of the target AWS region.
variable "aws_region" { default = "us-west-2" }

# The short name of the Mantl cluster. 
variable "cluster_short_name" {}

# The target domain name. 
variable "domain_name" {}

# The target AWS hosted zone Id. 
variable "hosted_zone_id" {}

# The number of control nodes in the Mantl cluster.
variable "control_count" {}

# The IPv4 addresses for all the control nodes in the Mantl cluster.
variable "control_ips" { type = "list" }

# The number of edge (externally-facing) nodes in the Mantl cluster.
variable "edge_count" {}

# The IPv4 addresses for all the edge nodes in the Mantl cluster.
variable "edge_ips" { type = "list" }

# The number of worker nodes in the Mantl cluster.
variable "worker_count" {}

# The IPv4 addresses for all the worker nodes in the Mantl cluster.
variable "worker_ips" { type = "list" }

# The number of Kubernetes worker nodes in the Mantl cluster.
variable "kubeworker_count" {}

# The IPv4 addresses for all the Kubernetes worker nodes in the Mantl cluster.
variable "kubeworker_ips" { type = "list" }

# Configure our AWS provider.
provider "aws" {
    region = "${var.aws_region}"
}

# Control nodes.
resource "aws_route53_record" "dns-control-node" {
    type    = "A"
    ttl     = 60
    zone_id = "${var.hosted_zone_id}"

    name    = "${var.cluster_short_name}-control-${format("%02d", count.index+1)}.node.${var.domain_name}"
    records = ["${element(var.control_ips, count.index)}"]
    
    count   = "${var.control_count}"
}

# Control nodes (group).
resource "aws_route53_record" "dns-control" {
    type    = "A"
    ttl     = 60
    zone_id = "${var.hosted_zone_id}"

    name    = "control.${var.domain_name}"
    records = ["${var.control_ips}"]
}

# Edge (externally-facing) nodes.
resource "aws_route53_record" "dns-edge-node" {
    type    = "A"
    ttl     = 60
    zone_id = "${var.hosted_zone_id}"

    name    = "${var.cluster_short_name}-edge-${format("%02d", count.index+1)}.node.${var.domain_name}"
    records = ["${element(var.edge_ips, count.index)}"]
    
    count   = "${var.edge_count}"
}

# Edge nodes wildcard (group).
resource "aws_route53_record" "dns-edge-wildcard" {
    type    = "A"
    ttl     = 60
    zone_id = "${var.hosted_zone_id}"

    name    = "*.${var.domain_name}"
    records = ["${var.edge_ips}"] # TODO: Consider changing this to use a CloudControl VIP.
}

# Worker nodes.
resource "aws_route53_record" "dns-worker-node" {
    type    = "A"
    ttl     = 60
    zone_id = "${var.hosted_zone_id}"

    name    = "${var.cluster_short_name}-worker-${format("%02d", count.index+1)}.node.${var.domain_name}"
    records = ["${element(var.worker_ips, count.index)}"]
    
    count   = "${var.worker_count}"
}

# Kubernetes worker nodes.
resource "aws_route53_record" "dns-kubeworker-node" {
    type    = "A"
    ttl     = 60
    zone_id = "${var.hosted_zone_id}"

    name    = "${var.cluster_short_name}-kubeworker-${format("%02d", count.index+1)}.node.${var.domain_name}"
    records = ["${element(var.kubeworker_ips, count.index)}"]
    
    count   = "${var.kubeworker_count}"
}

#########
# Outputs
#########

output "control_group_fqdn" {
    value = "${aws_route53_record.dns-control.fqdn}"
}

output "control_node_fqdns" {
    value = "${join(",", aws_route53_record.dns-control-node.*.fqdn)}"
}

output "edge_node_fqdns" {
    value = "${join(",", aws_route53_record.dns-edge-node.*.fqdn)}"
}

output "worker_node_fqdns" {
    value = "${join(",", aws_route53_record.dns-worker-node.*.fqdn)}"
}

output "kubeworker_node_fqdns" {
    value = "${join(",", aws_route53_record.dns-kubeworker-node.*.fqdn)}"
}
