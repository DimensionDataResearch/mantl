variable "host_count"  				{ default = 1 }
variable "host_ips"    				{ type = "list" }
variable "username"    				{ default = "root" }
variable "password"    				{ }
variable "ssh_key"     				{ }
variable "firewall_rule_dependency" { default = "" }

# Ugly workaround used to control module ordering.
data "null_data_source" "firewall_rule_dependency" {
	inputs = {
		ssh_rule_id		= "${var.firewall_rule_dependency}"
		
		# Could be any property, just needs to pass through the data source to establish a dependency.
		ssh_username	= "${var.username}"
	}
}

resource "null_resource" "install_ssh_key" {
    count = "${var.host_count}"

	# Install our SSH public key.
	provisioner "remote-exec" {
		inline = [
			"mkdir -p ~/.ssh",
			"chmod 700 ~/.ssh",
			"echo '${var.ssh_key}' > ~/.ssh/authorized_keys",
			"chmod 600 ~/.ssh/authorized_keys",
            "passwd -d ${var.username}"
		]

		connection {
			type 		= "ssh"
			
			username 	= "${data.null_data_source.firewall_rule_dependency.outputs["ssh_username"]}"
			password 	= "${var.password}"

			host 		= "${element(var.host_ips, count.index)}"
		}
	}
}
