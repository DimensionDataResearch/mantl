# Inputs
variable "client_public_ip"			{ }
variable "control_count"			{ }
variable "control_private_ipv4s"	{ type = "list" }
variable "edge_count"				{ }
variable "edge_private_ipv4s"		{ type = "list" }
variable "worker_count"				{ }
variable "worker_private_ipv4s"		{ type = "list" }
variable "kubeworker_count"			{ }
variable "kubeworker_private_ipv4s"	{ type = "list" }
variable "expose_servers"			{ default = false }
variable "expose_edge_insecure"		{ default = false }
variable "networkdomain"			{ }

# IP address lists
#
# Use these in firewall rules to address machines by role.
resource "ddcloud_address_list" "control_nodes" {
	name					= "ControlNodes"
	ip_version				= "IPv4"

	addresses				= ["${ddcloud_nat.control_node.*.public_ipv4}"]

	networkdomain			= "${var.networkdomain}"
}
resource "ddcloud_address_list" "edge_nodes" {
	name					= "EdgeNodes"
	ip_version				= "IPv4"

	addresses				= ["${ddcloud_nat.edge_node.*.public_ipv4}"]

	networkdomain			= "${var.networkdomain}"
}
resource "ddcloud_address_list" "worker_nodes" {
	name					= "WorkerNodes"
	ip_version				= "IPv4"

	addresses				= ["${ddcloud_nat.worker_node.*.public_ipv4}"]

	networkdomain			= "${var.networkdomain}"
}
resource "ddcloud_address_list" "kubeworker_nodes" {
	name					= "KubeWorkerNodes"
	ip_version				= "IPv4"

	addresses				= ["${ddcloud_nat.kubeworker_node.*.public_ipv4}"]

	networkdomain			= "${var.networkdomain}"
}

# Allow SSH for all machines (but only from the client IP)
#
# If you want to enable access for additional clients later, you can update is address list in the CloudControl UI
resource "ddcloud_address_list" "ssh_in" {
	name					= "SSH4.Inbound"
	ip_version				= "IPv4"

	addresses				= ["${var.client_public_ip}"]

	networkdomain			= "${var.networkdomain}"
}
resource "ddcloud_firewall_rule" "all_nodes_ssh4_in" {
	name 					= "ssh4.inbound"
	placement				= "first"
	action					= "accept" # Valid values are "accept" or "drop."
	
	ip_version				= "ipv4"
	protocol				= "tcp"

	source_address_list		= "${ddcloud_address_list.ssh_in.id}"

	destination_port 		= "22"

	networkdomain 			= "${var.networkdomain}"
}

# Control nodes
resource "ddcloud_nat" "control_node" {
    count           = "${var.control_count}"

    private_ipv4    = "${element(var.control_private_ipv4s, count.index)}"
    networkdomain   = "${var.networkdomain}"
}
resource "ddcloud_firewall_rule" "control_nodes_https4_in" {
	name 						= "control.https4.inbound"
	placement					= "first"
	action						= "accept" # Valid values are "accept" or "drop."
	enabled						= "${var.expose_servers}"
	
	ip_version					= "ipv4"
	protocol					= "tcp"

	destination_address_list	= "${ddcloud_address_list.control_nodes.id}"
	destination_port 			= "80"

	networkdomain 				= "${var.networkdomain}"
}

# Edge nodes
resource "ddcloud_nat" "edge_node" {
    count           = "${var.edge_count}"

    private_ipv4    = "${element(var.edge_private_ipv4s, count.index)}"
    networkdomain   = "${var.networkdomain}"
}
resource "ddcloud_firewall_rule" "edge_nodes_https4_in" {
	name 						= "edge.https4.inbound"
	placement					= "first"
	action						= "accept" # Valid values are "accept" or "drop."
	enabled						= "${var.expose_servers}"
	
	ip_version					= "ipv4"
	protocol					= "tcp"

	destination_address_list	= "${ddcloud_address_list.edge_nodes.id}"
	destination_port 			= "80"

	networkdomain 				= "${var.networkdomain}"
}
resource "ddcloud_firewall_rule" "edge_nodes_http4_in" {
    name 						= "edge.http4.inbound"
	placement					= "first"
	action						= "accept" # Valid values are "accept" or "drop."
	enabled						= "${var.expose_edge_insecure}"
	
	ip_version					= "ipv4"
	protocol					= "tcp"

	destination_address_list	= "${ddcloud_address_list.edge_nodes.id}"
	destination_port 			= "80"

	networkdomain 				= "${var.networkdomain}"
}

# Worker nodes
resource "ddcloud_nat" "worker_node" {
    count           = "${var.worker_count}"

    private_ipv4    = "${element(var.worker_private_ipv4s, count.index)}"
    networkdomain   = "${var.networkdomain}"
}

# Kubernetes worker nodes
resource "ddcloud_nat" "kubeworker_node" {
    count           = "${var.kubeworker_count}"

    private_ipv4    = "${element(var.kubeworker_private_ipv4s, count.index)}"
    networkdomain   = "${var.networkdomain}"
}

# Ugly workaround used to control module ordering.
data "null_data_source" "firewall_rule_dependency" {
	inputs = {
		# Could be any property, just need to publish a value for another module to consume.
		ssh_rule_id	= "${ddcloud_firewall_rule.all_nodes_ssh4_in.id}"
	}

	depends_on = [
		"ddcloud_firewall_rule.all_nodes_ssh4_in"
	]
}

# Outputs
output "control_public_ipv4s" {
    value = ["${ddcloud_nat.control_node.*.public_ipv4}"]
}
output "edge_public_ipv4s" {
    value = ["${ddcloud_nat.edge_node.*.public_ipv4}"]
}
output "worker_public_ipv4s" {
    value = ["${ddcloud_nat.worker_node.*.public_ipv4}"]
}
output "kubeworker_public_ipv4s" {
    value = ["${ddcloud_nat.kubeworker_node.*.public_ipv4}"]
}
output "firewall_rule_dependency_ssh" {
	value = "${data.null_data_source.firewall_rule_dependency.outputs["ssh_rule_id"]}"
}