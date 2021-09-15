# Install VM use `virt-install`

[redhat-guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-guest_virtual_machine_installation_overview-creating_guests_with_virt_install)

## install without graphics

```shell
virt-install \
--name=centos8-1 \
--memory 2048 \
--vcpus 2 \
--disk size=20,path=/home/signal/vm/centos8-1.qcow2 \
--location /var/lib/libvirt/images/CentOS-8.4.2105-x86_64-dvd1.iso \
--os-variant rhel8.0 \
--network=default \
--graphics none \
--virt-type=kvm \
--console pty,target_type=serial \
--extra-args 'console=ttyS0,115200n8 serial' \
--force --debug
```
