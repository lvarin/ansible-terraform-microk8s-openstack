# Variables
variable "instance_master_name" {
  type = string
  default = "microk8s-master" # Name of the VM to create
}

variable "instance_prefix" {
  type = string
  default = "microk8s-node" # Name of the VM to create
}

variable "instance_count" {
  type = string
  default = "2" # Number of node VMs
}  
# Leave it to 1

variable "keypair" {
  type    = string
  default = "alvaro-key"   # name of keypair that will have access to the VM
}

variable "network" {
  type    = string
  default = "project_2001316" # default network to be used
}

# Data sources
## Get Image ID
data "openstack_images_image_v2" "image" {
  name        = "CentOS-7" # Name of image to be used
  most_recent = true
}

variable "private_key_path" {
  description = "Path to the private SSH key, used to access the instance."
  default     = "~/.ssh/alvaro-key" # path where terraform will find the private key
}

variable "ssh_user" {
  description = "SSH user name to connect to your instance."
  default     = "cloud-user"
}
