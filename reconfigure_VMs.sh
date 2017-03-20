#!/bin/bash
# NIC types. Boot NIC must be intel or AMD. Other NICs can be virtio
# Types: 82540EM, 82545EM, 82543GC, Am79C973, virtio

source ./config.sh
source ./functions/memory.sh

total_memory=$(get_available_memory)

vbox_vm_flags=""
vbox_vm_flags="${vbox_vm_flags} --nestedpaging on"
vbox_vm_flags="${vbox_vm_flags} --vtxvpid on"
vbox_vm_flags="${vbox_vm_flags} --vtxux on"
vbox_vm_flags="${vbox_vm_flags} --largepages on"
vbox_vm_flags="${vbox_vm_flags} --chipset piix3"
vbox_vm_flags="${vbox_vm_flags} --largepages on"
vbox_vm_flags="${vbox_vm_flags} --pae off"
vbox_vm_flags="${vbox_vm_flags} --apic on"
vbox_vm_flags="${vbox_vm_flags} --x2apic on"
vbox_vm_flags="${vbox_vm_flags} --longmode on"
vbox_vm_flags="${vbox_vm_flags} --hpet off"
vbox_vm_flags="${vbox_vm_flags} --hwvirtex on"
vbox_vm_flags="${vbox_vm_flags} --triplefaultreset off"
vm_slave_first_disk_mb=131072

if [ $total_memory -gt 67108864 ]; then
	vbox_vm_flags="${vbox_vm_flags} --pagefusion off"
	ctrl_mem=24576
	ctrl_cpus=4
	cmpt_mem=8256
	cmpt_cpus=2
else
	vbox_vm_flags="${vbox_vm_flags} --pagefusion on"
	ctrl_mem=12800
	ctrl_cpus=2
	cmpt_mem=6272
	cmpt_cpus=2
fi

echo "(II) CONFIG_FOR: $((${total_memory}/(1024)))Mb, CTRL_MEM: ${ctrl_mem}Mb. CTRL_CPUS: ${ctrl_cpus}"
echo "(II) Final flags: ${vbox_vm_flags}"

for i in {1..16}
do
	name="osp-baremetal-${i}"
	echo "(II) Reconfiguring VM ${name}..."
	VBoxManage modifyvm ${name} ${vbox_vm_flags}
done

for i in 1
do
	name="osp-instack"
	echo "(II) Reconfiguring VM ${name}..."
	VBoxManage modifyvm ${name} ${vbox_vm_flags}
done

# RAM/cpus might be different for controllers...
echo "(II) Reconfiguring Controllers : --memory ${ctrl_mem} --cpus ${ctrl_cpus}, disk0 --resize ${vm_slave_first_disk_mb}..."
vboxmanage modifyvm osp-instack --memory ${ctrl_mem} --cpus ${ctrl_cpus} 
for i in $(seq 1 3); do
	vboxmanage modifyvm osp-baremetal-${i} --memory ${ctrl_mem} --cpus ${ctrl_cpus}
	disk_path=$(vboxmanage showvminfo osp-baremetal-${i}|grep 'SATA (0, 0)'|awk '{ print $4}')
	vboxmanage modifyhd ${disk_path} --resize ${vm_slave_first_disk_mb}
	vboxmanage storagectl osp-baremetal-${i} --name SATA --hostiocache on
done

echo "(II) Reconfiguring Other Nodes : --memory ${cmpt_mem} --cpus ${cmpt_cpus}, disk0 --resize ${vm_slave_first_disk_mb}..."
# Computes/ceph/etc...
for i in $(seq 4 16); do
	vboxmanage modifyvm osp-baremetal-${i} --memory ${cmpt_mem} --cpus ${cmpt_cpus}
	disk_path=$(vboxmanage showvminfo osp-baremetal-${i}|grep 'SATA (0, 0)'|awk '{ print $4}')
	vboxmanage modifyhd ${disk_path} --resize ${vm_slave_first_disk_mb}
	vboxmanage storagectl osp-baremetal-${i} --name SATA --hostiocache on
done
