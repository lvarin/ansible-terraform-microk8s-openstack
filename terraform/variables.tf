# Compulsory variables
variable "keypair" {
  type    = string
  default = "XXXXX"   # name of keypair that will have access to the VMs
}

variable "network" {
  type    = string
  default = "project_YYYYY" # default network to be used
}

variable "private_key_path" {
  description = "Path to the private SSH key, used to access the instance."
  default     = "~/.ssh/XXXXX" # path where terraform will find the private key
}

variable "cidr_list" {
  default = {
  "cscOfice1" = "193.166.1.0/24"
  "cscOfice2" = "193.166.2.0/24"
  "cscOfice3" = "193.166.80.0/23"
  "vpnstaff"  = "193.166.85.0/24"
  }
}

# Configuration variables

variable "instance_count" {
  type = string
  default = "0" # Number of node VMs
}

variable "flavor" {
  description = "Flavor to be used"
  default     = "standard.medium"
}

variable "nfs_volume_size" {
  description = "Size in Gigabytes of the NFS volume"
  default = 50
}
# Other

variable "instance_master_name" {
  type = string
  default = "microk8s-master" # Name of the VM to create
}

variable "instance_prefix" {
  type = string
  default = "microk8s-node" # Name of the VM to create
}

variable "nfs_node_name" {
  type = string
  default = "microk8s-nfs"
}

data "openstack_images_image_v2" "image" {
  name        = "Ubuntu-20.04" # Name of image to be used
  most_recent = true
}

variable "ssh_user" {
  description = "SSH user name to connect to your instance."
  default     = "ubuntu"
}

variable "control_port" {
  default = 16443
}
