## Get flavor id
data "openstack_compute_flavor_v2" "flavor" {
  name = "${var.flavor}" # flavor to be used
}


resource "openstack_networking_secgroup_v2" "secgroup_ssh" {
  name = "SSH-microk8s"
  description = "SSH connection from CSC to microk8s"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_22" {
  for_each          = toset(split(",", var.cidr_ssh))
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
  for_each          = toset(split(",", var.cidr_list))
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.control_port
  port_range_max    = var.control_port
  remote_ip_prefix  = each.value
  security_group_id = "${openstack_networking_secgroup_v2.HTTP_microk8s.id}"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_443" {
  for_each          = toset(split(",",var.cidr_list))
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

resource "openstack_blockstorage_volume_v2" "volume_1" {
  name        = "microk8s-nfs"
  description = "first test volume"
  size        = var.nfs_volume_size
}

resource "openstack_compute_instance_v2" "nfs" {
  name            = "${var.nfs_node_name}"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.keypair
  security_groups = ["${openstack_compute_secgroup_v2.internal_microk8s.id}"]
  network {
    name = var.network
  }
}

resource "openstack_compute_volume_attach_v2" "va_1" {
  instance_id = "${openstack_compute_instance_v2.nfs.id}"
  volume_id   = "${openstack_blockstorage_volume_v2.volume_1.id}"
  device      = "/dev/vdb"
}

# Create "instance_count" instances
resource "openstack_compute_instance_v2" "server" {
  name            = "${var.instance_prefix}-${count.index}"
  count           = "${var.instance_count}"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.keypair
  security_groups = ["${openstack_compute_secgroup_v2.internal_microk8s.id}"]

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
        "ssh_args"         : "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
      } ],
      [ for key, item in openstack_compute_instance_v2.server :
        {
        "groups"           : "['compute']",
        "name"             : item.name,
        "ip"               : item.access_ip_v4,
        "ansible_ssh_user" : "${var.ssh_user}",
        "ssh_args"         : "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o \"ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ${var.ssh_user}@${openstack_networking_floatingip_v2.fip1.address}\""
      } ],
      [
        {
          "groups"           : "['nfs']",
          "name"             : "${openstack_compute_instance_v2.nfs.name}",
          "ip"               : "${openstack_compute_instance_v2.nfs.access_ip_v4}"
          "ansible_ssh_user" : "${var.ssh_user}",
          "ssh_args"         : "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o \"ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ${var.ssh_user}@${openstack_networking_floatingip_v2.fip1.address}\""
        }]
  )
}

