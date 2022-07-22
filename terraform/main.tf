## Get flavor id
data "openstack_compute_flavor_v2" "flavor" {
  name = "standard.tiny" # flavor to be used
}

resource "openstack_compute_secgroup_v2" "secgroup_ssh" {
  name = "SSH-microk8s"
  description = "my security group"

  rule {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
  }
}

# Create the master
resource "openstack_compute_instance_v2" "master" {
  name            = "${var.instance_master_name}"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.keypair
  security_groups = ["${openstack_compute_secgroup_v2.secgroup_ssh.id}"]
  network {
    name = var.network
  }
}

# Create "instance_count" instances
resource "openstack_compute_instance_v2" "server" {
  name            = "${var.instance_prefix}-${count.index}"
  count          = "${var.instance_count}"
  image_id        = data.openstack_images_image_v2.image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.keypair
  #security_groups = ["${openstack_compute_secgroup_v2.secgroup_ssh.id}"]
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
        "groups"           : "['jump_hosts']",
        "name"             : "${openstack_compute_instance_v2.master.name}",
        "ip"               : "${openstack_networking_floatingip_v2.fip1.address}",
        "ansible_ssh_user" : "${var.ssh_user}",
        "private_key_file" : "${var.private_key_path}",
        "ssh_args"         : "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
      } ],
      [ for key, item in openstack_compute_instance_v2.server : 
        {
        "groups"           : "['target_hosts']",
        "name"             : item.name,
        "ip"               : item.network.0.fixed_ip_v4,
        "ansible_ssh_user" : "${var.ssh_user}",
        "private_key_file" : "${var.private_key_path}",
        "ssh_args"         : "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o \"ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.private_key_path} -W %h:%p ${var.ssh_user}@${openstack_networking_floatingip_v2.fip1.address}\""
      } ]
  )
}

