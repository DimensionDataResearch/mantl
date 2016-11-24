# The name of the  CloudControl region (e.g. AU, NA, EU) in which Mantl will be deployed.
variable "region" { }

# The target data centre in which Mantl will be deployed.
variable "datacenter" { }

# A short name for the Mantl cluster. 
variable "cluster_short_name" { }

# The Consul data center identifier for the data center where Mantl is being deployed. 
variable "consul_dc" { default = "au9" }

# Expose servers via public IP addresses (enable firewall ingress rules)?
variable "expose_servers" { default = false }

# In addition to HTTPS, allow HTTP connections to the edge servers?
variable "expose_edge_insecure" { default = false }

# The top-level domain name to use.
variable "domain_name" { }

# The sub-domain name to use (services will appear as "*.subdomain_name.domain_name".
variable "subdomain_name" { }

# The AWS hosted zone Id associated with this domain.
variable "aws_hosted_zone_id" { default = "ZOBD4EJVNNOC4" }

# The cluster VLAN's IP network address.
variable "cluster_vlan_network_address" { default = "10.5.50.0/24" }

# The last quad of the first IP address used by the cluster (i.e. without cluster_vlan_address_base).
variable "cluster_vlan_address_start" { default = 20 }

# Automatically start servers after they are deployed?
variable "server_auto_start" { default = true }

# The size of the OS (root) volume for all deployed servers in the cluster.
#
# Cannot be less than 10.
variable "os_disk_size_gb" { default = 10 }

# The size of the data volume for all deployed servers in the cluster (the root file system will be extended onto it).
variable "data_disk_size_gb" { default = 20 }

# The initial root password used to bootstrap SSH key authentication for machines in the cluster.
#
# Password authentication is disabled once the SSH key has been installed. 
variable "ssh_bootstrap_password" { }

# The SSH public key file to use for authentication to machines in the cluster.
variable "ssh_key_file" { default = "~/.ssh/id_rsa.pub" }

# The public (external) IP address of the machine running Terraform.
#
# Used when configuring the firewall to permit inbound SSH connections.
variable "client_public_ip" { }

# Provider configuration
provider "ddcloud" {
    region = "${var.region}"
}

# Control nodes.
variable "control_count" { default = 3 }
variable "control_cpu_count" { default = 4 }
variable "control_memory_gb" { default = 8 }
variable "control_address_start" { default = 0 }        # Added to cluster_vlan_address_start

# Edge (public-facing) nodes.
variable "edge_count" { default = 2 }
variable "edge_cpu_count" { default = 4 }
variable "edge_memory_gb" { default = 6 }
variable "edge_address_start" { default = 5 }

# Worker nodes.
variable "worker_count" { default = 4 }
variable "worker_cpu_count" { default = 4 }
variable "worker_memory_gb" { default = 8 }
variable "worker_address_start" { default = 10 }        # Added to cluster_vlan_address_start

# Kubernetes worker nodes.
variable "kubeworker_count" { default = 2 }
variable "kubeworker_cpu_count" { default = 4 }
variable "kubeworker_memory_gb" { default = 8 }
variable "kubeworker_address_start" { default = 15 }    # Added to cluster_vlan_address_start

#########
# Network
#########

module "networkdomain" {
    source                      = "./network/networkdomain"
    
    name                        = "Mantl"
    description                 = "Cisco Mantl"
    datacenter                  = "${var.datacenter}"
}
module "vlan" {
    source                      = "./network/vlan"

    name                        = "Mantl primary VLAN"
    description                 = "Primary VLAN for Mantl."
    base_address                = "${element(split("/", var.cluster_vlan_network_address), 0)}"
    prefix_size                 = "${element(split("/", var.cluster_vlan_network_address), 1)}"

    networkdomain               = "${module.networkdomain.id}"
}
module "public_ips" {
    source                      = "./network/public-ip"
    
    control_count               = "${var.control_count}"
    control_private_ipv4s       = "${module.control_nodes.ipv4s}"

    edge_count                  = "${var.edge_count}"
    edge_private_ipv4s          = "${module.edge_nodes.ipv4s}"

    worker_count                = "${var.worker_count}"
    worker_private_ipv4s        = "${module.worker_nodes.ipv4s}"

    kubeworker_count            = "${var.kubeworker_count}"
    kubeworker_private_ipv4s    = "${module.kubeworker_nodes.ipv4s}"

    expose_servers              = "${var.expose_servers}"
    expose_edge_insecure        = "${var.expose_edge_insecure}"

    client_public_ip            = "${var.client_public_ip}"

    networkdomain               = "${module.networkdomain.id}"
}
module "dns" {
    source                      = "./network/dns/aws"

    cluster_short_name          = "${var.cluster_short_name}"
    domain_name                 = "${var.subdomain_name}.${var.domain_name}"
    hosted_zone_id              = "${var.aws_hosted_zone_id}"

    control_count               = "${var.control_count}"
    control_ips                 = "${module.public_ips.control_public_ipv4s}"
    
    edge_count                  = "${var.edge_count}"
    edge_ips                    = "${module.public_ips.edge_public_ipv4s}"

    worker_count                = "${var.worker_count}"
    worker_ips                  = "${module.public_ips.worker_public_ipv4s}"

    kubeworker_count            = "${var.kubeworker_count}"
    kubeworker_ips              = "${module.public_ips.kubeworker_public_ipv4s}"
}

#########
# Servers
#########

module "control_nodes" {
    source              = "./server"
    count               = "${var.control_count}"

    role                = "control"
    consul_dc           = "${var.consul_dc}"
    name                = "${var.cluster_short_name}"
    description         = "Control node {} for ${var.cluster_short_name} cluster."
    admin_password      = "${var.ssh_bootstrap_password}"
    auto_start          = "${var.server_auto_start}"

    memory_gb           = "${var.control_memory_gb}"
    cpu_count           = "${var.control_cpu_count}"
    os_disk_size_gb     = "${var.os_disk_size_gb}"
    data_disk_size_gb   = "${var.data_disk_size_gb}"

    networkdomain       = "${module.networkdomain.id}"
    vlan                = "${module.vlan.id}"
    ipv4_network        = "${var.cluster_vlan_network_address}"
    ipv4_start          = "${var.cluster_vlan_address_start + var.control_address_start}"
}
module "edge_nodes" {
    source              = "./server"
    count               = "${var.edge_count}"

    role                = "edge"
    consul_dc           = "${var.consul_dc}"
    name                = "${var.cluster_short_name}"
    description         = "Edge node {} for ${var.cluster_short_name} cluster."
    admin_password      = "${var.ssh_bootstrap_password}"
    auto_start          = "${var.server_auto_start}"

    memory_gb           = "${var.edge_memory_gb}"
    cpu_count           = "${var.edge_cpu_count}"
    os_disk_size_gb     = "${var.os_disk_size_gb}"
    data_disk_size_gb   = "${var.data_disk_size_gb}"

    networkdomain       = "${module.networkdomain.id}"
    vlan                = "${module.vlan.id}"
    ipv4_network        = "${var.cluster_vlan_network_address}"
    ipv4_start          = "${var.cluster_vlan_address_start + var.edge_address_start}"
}
module "worker_nodes" {
    source              = "./server"
    count               = "${var.worker_count}"

    role                = "worker"
    consul_dc           = "${var.consul_dc}"
    name                = "${var.cluster_short_name}"
    description         = "Worker node {} for ${var.cluster_short_name} cluster."
    admin_password      = "${var.ssh_bootstrap_password}"
    auto_start          = "${var.server_auto_start}"

    memory_gb           = "${var.worker_memory_gb}"
    cpu_count           = "${var.worker_cpu_count}"
    os_disk_size_gb     = "${var.os_disk_size_gb}"
    data_disk_size_gb   = "${var.data_disk_size_gb}"

    networkdomain       = "${module.networkdomain.id}"
    vlan                = "${module.vlan.id}"
    ipv4_network        = "${var.cluster_vlan_network_address}"
    ipv4_start          = "${var.cluster_vlan_address_start + var.worker_address_start}"
}
module "kubeworker_nodes" {
    source              = "./server"
    count               = "${var.kubeworker_count}"

    role                = "kubeworker"
    consul_dc           = "${var.consul_dc}"
    name                = "${var.cluster_short_name}"
    description         = "Kubernetes worker node {} for ${var.cluster_short_name} cluster."
    admin_password      = "${var.ssh_bootstrap_password}"
    auto_start          = "${var.server_auto_start}"

    memory_gb           = "${var.kubeworker_memory_gb}"
    cpu_count           = "${var.kubeworker_cpu_count}"
    os_disk_size_gb     = "${var.os_disk_size_gb}"
    data_disk_size_gb   = "${var.data_disk_size_gb}"

    networkdomain       = "${module.networkdomain.id}"
    vlan                = "${module.vlan.id}"
    ipv4_network        = "${var.cluster_vlan_network_address}"
    ipv4_start          = "${var.cluster_vlan_address_start + var.kubeworker_address_start}"
}

###############
# SSH bootstrap
###############

module "control_nodes_ssh" {
    source                      = "./ssh"

    host_count                  = "${var.control_count}"
    host_ips                    = ["${module.public_ips.control_public_ipv4s}"]
    password                    = "${var.ssh_bootstrap_password}"
    ssh_key                     = "${file(var.ssh_key_file)}"

    # Ugly workaround for Terraform's lack of support for inter-module dependencies.
    firewall_rule_dependency    = "${module.public_ips.firewall_rule_dependency_ssh}"
}
module "edge_nodes_ssh" {
    source                      = "./ssh"

    host_count                  = "${var.edge_count}"
    host_ips                    = ["${module.public_ips.edge_public_ipv4s}"]
    password                    = "${var.ssh_bootstrap_password}"
    ssh_key                     = "${file(var.ssh_key_file)}"

    # Ugly workaround for Terraform's lack of support for inter-module dependencies.
    firewall_rule_dependency    = "${module.public_ips.firewall_rule_dependency_ssh}"
}
module "worker_nodes_ssh" {
    source                      = "./ssh"

    host_count                  = "${var.worker_count}"
    host_ips                    = ["${module.public_ips.worker_public_ipv4s}"]
    password                    = "${var.ssh_bootstrap_password}"
    ssh_key                     = "${file(var.ssh_key_file)}"

    # Ugly workaround for Terraform's lack of support for inter-module dependencies.
    firewall_rule_dependency    = "${module.public_ips.firewall_rule_dependency_ssh}"
}
module "kubeworker_nodes_ssh" {
    source                      = "./ssh"

    host_count                  = "${var.kubeworker_count}"
    host_ips                    = ["${module.public_ips.kubeworker_public_ipv4s}"]
    password                    = "${var.ssh_bootstrap_password}"
    ssh_key                     = "${file(var.ssh_key_file)}"

    # Ugly workaround for Terraform's lack of support for inter-module dependencies.
    firewall_rule_dependency    = "${module.public_ips.firewall_rule_dependency_ssh}"
}

###############
# Final outputs
###############

output "fqdn_control" {
    value = "control.${var.subdomain_name}.${var.domain_name}" 
}
output "fqdn_wildcard" {
    value = "*.${var.subdomain_name}.${var.domain_name}" 
}
output "ipv4_control_nodes" {
    value = "${module.control_nodes.ipv4s}"
}
output "ipv4_edge_nodes" {
    value = "${module.edge_nodes.ipv4s}"
}
output "ipv4_worker_nodes" {
    value = "${module.worker_nodes.ipv4s}"
}
output "ipv4_kubeworker_nodes" {
    value = "${module.kubeworker_nodes.ipv4s}"
}
