terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">1.26.0"
    }
  }
}

provider "openstack" {}
