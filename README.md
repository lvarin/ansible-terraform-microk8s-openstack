# Terraform Ansible microk8s OpenStack

This is an example on how to deploy a microk8s cluster in an OpenStack instance using Terraform and ansible. It is based on the following repositories:

* https://github.com/lvarin/ansible-terraform-example.git
* https://github.com/fabianlee/microk8s-nginx-istio.git
* https://github.com/istvano/ansible_role_microk8s
* https://fabianlee.org/2021/07/25/kubernetes-microk8s-cluster-on-ubuntu-using-ansible/

## Quick start

* [Install terraform](https://www.terraform.io/downloads.html)

* Log in Openstack sourcing the openrc file that your Openstack instance provides.

* Edit `terraform/variables.tf` with the correct values for the name of **keypair** (`openstack keypair list`), **network** (`openstack network list`) and **security_groups** (`openstack security group list`).

```sh
ansible-playbook site.yaml
```