# Terraform+Ansible microk8s OpenStack deployment

This is an example of how to deploy a microk8s cluster in an OpenStack instance using Terraform and Ansible. It is based on the following repositories:

* <https://github.com/lvarin/ansible-terraform-example.git>
* <https://github.com/fabianlee/microk8s-nginx-istio.git>
* <https://github.com/istvano/ansible_role_microk8s>
* <https://fabianlee.org/2021/07/25/kubernetes-microk8s-cluster-on-ubuntu-using-ansible/>

## Quick start

* [Install terraform](https://www.terraform.io/downloads.html)

* Log in to Openstack sourcing the openrc file that your Openstack instance provides.

```sh
. project_YYYXXXX-openrc.sh
```

Currently there are two files used to configure this deployment: `terraform/variables.tf` and `group_vars/all`.

* In `terraform/variables.tf` you need to fill up the compulsory variables:
  * **keypair**, this is the name of the public ssh key stored in OpenStack that will be added to the Virtual Machines. You can get the list of keys installed in OpenStack with `openstack keypair list`. You must choose one key from the lists that have your public keys.
  * **network**, this is the name of the network the Virtual Machines will be attached to. You can get the list with `openstack network list`.
  * **private_key_path**, this is the path on your computer where Terraform will find the private key. This private key has to be the pair of the public key selected in _keypair_.
  * **cidr_list**, a list of CIDRs (an IP range) that will be able to access the cluster.

  The other variables have sensible defaults. You may check them out and change them to tune the cluster configuration.
  * **instance_count**, number of worker nodes. With 0 worker nodes (the default) the master node will run the applications.
  * **flavor**, Openstack flavor for the Virtual Machines.
  * **nfs_volume_size**, size in Gigabytes for the NFS volume. Resize is not supported, when changing the size, a cluster recreation is recommended.
  * **instance_master_name**, name of the master Virtual machine.
  * **instance_prefix**, a prefix of the name of the worker nodes. A hyphen and a number will be added to form the worker node name. By default, the first node will be called `microk8s-node-0`, the second `microk8s-node-1`, and so on.
  * **nfs_node_name**, name of the NFS virtual machine.
  * **ssh_user**, name of the username to login into the Virtual machines. It must correspond to the one configured on the OS image used.

* In `group_vars/all` all variables have sensitive defaults.
  * **microk8s_version**, the version to install.
  * **microk8s_plugins**, allows to enable or disable individual `microk8s` plugins.
  * **microk8s_user**, same user as _ssh_user_.

After all variables are properly set, simply run:

```sh
ansible-playbook site.yaml
```

This will deploy the Virtual Machines and configure them. The cluster will be ready for use.

### Kubectl configuration

`kubectl` is the command line tool to interact with a Kubernetes cluster. The master node has `kubectl` installed by default. It is possible to install and configure `kubectl` in any remote computer to interact with this cluster. There are 3 steps:

1. [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
1. Make sure that the computer's IP belongs to one of the CIDRs configured in _cidr_list_.
1. Generate and copy a `config` file:

  ```sh
  ssh ubuntu@<microk8s_master> microk8s.config >config
```

**Note:** Replace `<microk8s_master>` with the master's floating ip.

**Note 2:** In order to tell kubectl where is the config file simply do `kubectl --kubeconfig config`. Or copy it to the default path: `$HOME/.kube/config`.

## Un-deploy

```sh
terraform -chdir=terraform destroy
```

**This will destroy the cluster and all its data**
