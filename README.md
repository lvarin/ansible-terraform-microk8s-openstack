# Terraform+Ansible microk8s OpenStack deployment

This is an example of how to deploy a microk8s cluster in an OpenStack instance using Terraform and Ansible. It is based on the following repositories:

* <https://github.com/lvarin/ansible-terraform-example.git>
* <https://github.com/fabianlee/microk8s-nginx-istio.git>
* <https://github.com/istvano/ansible_role_microk8s>
* <https://fabianlee.org/2021/07/25/kubernetes-microk8s-cluster-on-ubuntu-using-ansible/>

## Quick start

* [Install terraform](https://www.terraform.io/downloads.html)

* Install ansible `>2.10` or above, use Python `v3.8` or above:

```sh
pip install ansible
```

* Log in Openstack sourcing the openrc file that your Openstack instance provides.

```sh
. project_YYYXXXX-openrc.sh
```

In order to configure this deployment the file `group_vars/all` must be used.

|Name|Description|Default|
|-:|:-|:-:|
|**network**|this is the name of the network the Virtual Machines will be attached to. You can get the list with `openstack network list`.|-|
|**keypair**|this is the name of the public ssh key stored in OpenStack that will be added to the Virtual Machines. You can get the list of keys installed in OpenStack with `openstack keypair list`. You must choose one key from that list.|-|
|**private_key_path**|this is the path on you computer where Terraform will find the private key. This private key has to be the pair of the public key selected in _keypair_.|-|
|**cidr_list**|list of CIDRs (an IP range) that will be able to access the cluster.|`193.166.1.0/24,193.166.2.0/24, 193.166.80.0/23, 193.166.85.0/24`|
|**cidr_ssh**|list of CIDRs (an IP range) that will be able to SSH to the cluster nodes| `0.0.0.0/0` # Any IP|
|**instance_count**|number of worker nodes.|0 # the master node will run the applications|
|**flavor**|Openstack flavor for the Virtual Machines.|`standard.medium`|
|**nfs_volume_size**|size in Gigabyes for the NFS volume. Resize is not supported, when changing the size, a cluster recreation is recommended.|`50`|
|**instance_master_name**|name of the master Virtual machine.|`microk8s-master`|
|**instance_prefix**|prefix of the name of the worker nodes. A hiphen and a number will be added to form the worker node name. By default the first node will be called `microk8s-node-0`, the second `microk8s-node-1` and so on.|`microk8s-node`|
|**nfs_node_name**|name of the NFS virtual machine.|`microk8s-nfs`|
|**ssh_user**|name of the username to login in the Virtual machines. It must correspond to the one configured on the OS image used.|`ubuntu`|
|**microk8s_version**, version to install.|`1.24`|
|**microk8s_plugins**, allows to enable or disable individual `microk8s` plugins.||

After all variables are properly set, simply run:

```sh
terraform -chdir=terraform init
# This must be run only once to initiliaze Terraform's plugins
ansible-playbook site.yaml
```

This will deploy the Virtual Machines and configure them. The cluster will be ready for use.

### Kubectl configuration

`kubectl` is the command line tool to interact with a Kubernetes cluster. The master node has `kubectl` installed by default. It is possible to install and configure `kubectl` in any remote computer to interact with this cluster. There are 3 steps:

1. [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
1. Make sure that the computer's IP belongs to one of the CIDRs configured in _cidr_list_.
1. Generate and copy a `config` file:

  ```sh
  export MASTER_IP=<microk8s_master>
  ssh ubuntu@$MASTER_IP microk8s.config >config
  sed -i "s#\(server: https://\)[0-9\.]*:#\1$MASTER_IP:#" config
```

**Note:** Replace `<microk8s_master>` with the master's floating ip

**Note 2:** In order to tell kubectl where is the config file simply do `kubectl --kubeconfig config`. Or copy it to the default path: `$HOME/.kube/config`.

### Example application deployment

We will deploy a minimal example, with an `Ingress`, `Service` and `Deployment`

1. Edit `examples/ingress.yaml` and change `XXXX.kaj.pouta.csc.fi` for the DNS of the master's floating ip.

1. Run kubectl create

	```sh
	kubectl --kubeconfig config create -f examples/deployment.yaml -f examples/service.yaml -f examples/ingress.yaml
	```

1. Visit `http://<microk8s_master>/` you should be greeted by:

	`"Directory listing for /"`

## Un-deploy

```sh
terraform -chdir=terraform destroy
```

**This will destroy the cluster and all its data**
