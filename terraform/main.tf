## Get flavor id
data "openstack_compute_flavor_v2" "flavor" {
  name = "${var.flavor}" # flavor to be used
}

variable "cidr_list" {
  default = {
  "cscOfice1" = "193.166.1.0/24"
  "cscOfice2" = "193.166.2.0/24"
  "cscOfice3" = "193.166.80.0/23"
  "vpnstaff"  = "193.166.85.0/24"
  }
}

resource "openstack_networking_secgroup_v2" "secgroup_ssh" {
  name = "SSH-microk8s"
  description = "SSH connection from CSC to microk8s"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_22" {
  for_each          = var.cidr_list
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
  security_group_id = "${openstack_networking_secgroup_v2.secgroup_ssh.id}"
}

resource "openstack_compute_secgroup_v2" "internal_microk8s" {
  name = "internal-microk8s"
  description = "Internal microk8s traffic"

  rule {
    from_port = 1
    to_port = 65535
    ip_protocol = "tcp"
    cidr = "192.168.0.0/16"
  }

  rule {
    from_port = 1
    to_port = 65535
    ip_protocol = "udp"
    cidr = "192.168.0.0/16"
  }
}

resource "openstack_networking_secgroup_v2" "HTTP_microk8s" {
  name = "HTTPS-microk8s"
  description = "External traffic to HTTPs"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_16443" {
  for_each          = var.cidr_list
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 16443
  port_range_max    = 16443
  remote_ip_prefix  = each.value
  security_group_id = "${openstack_networking_secgroup_v2.HTTP_microk8s.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_443" {
  for_each          = var.cidr_list
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = each.value
  security_group_id = "${openstack_networking_secgroup_v2.HTTP_microk8s.id}"
}

# Create the master
resource "openstack_compute_instance_v2" "master" {
  name            = "${var.instance_master_name}"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.keypair
  security_groups = ["${openstack_networking_secgroup_v2.secgroup_ssh.id}",
                     "${openstack_compute_secgroup_v2.internal_microk8s.id}",
                     "${openstack_networking_secgroup_v2.HTTP_microk8s.id}"
                    ]
  network {
    name = var.network
  }
}

# TODO do not use the same key for inernal and external connections
# create a new one for the master to connect to nodes

# Create "instance_count" instances
resource "openstack_compute_instance_v2" "server" {
  name            = "${var.instance_prefix}-${count.index}"
  count          = "${var.instance_count}"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.keypair
  security_groups = ["${openstack_networking_secgroup_v2.secgroup_ssh.id}",
                     "${openstack_compute_secgroup_v2.internal_microk8s.id}"
                    ]
  network {
    name = var.network
  }
}

# Add Floating ip

resource "openstack_networking_floatingip_v2" "fip1" {
  pool = "public"
}

resource "openstack_compute_floatingip_associate_v2" "fip1" {
  floating_ip = openstack_networking_floatingip_v2.fip1.address
  instance_id = openstack_compute_instance_v2.master.id

  provisioner "remote-exec" {
    inline = ["echo 'Hello World'"]

    connection {
      type        = "ssh"
      user        = "${var.ssh_user}"
      host        = "${openstack_networking_floatingip_v2.fip1.address}"
      private_key = "${file("${var.private_key_path}")}"
    }
  }
}

output "inventory" {
  value = concat(
      [ {
        "groups"           : "['master']",
        "name"             : "${openstack_compute_instance_v2.master.name}",
        "ip"               : "${openstack_networking_floatingip_v2.fip1.address}",
        "ansible_ssh_user" : "${var.ssh_user}",
        "private_key_file" : "${var.private_key_path}",
        "ssh_args"         : "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
      } ],
      [ for key, item in openstack_compute_instance_v2.server : 
        {
        "groups"           : "['compute']",
        "name"             : item.name,
        "ip"               : item.network.0.fixed_ip_v4,
        "ansible_ssh_user" : "${var.ssh_user}",
        "private_key_file" : "${var.private_key_path}",
        "ssh_args"         : "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o \"ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.private_key_path} -W %h:%p ${var.ssh_user}@${openstack_networking_floatingip_v2.fip1.address}\""
      } ]
  )
}

