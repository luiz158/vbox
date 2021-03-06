#!/bin/bash

#    Copyright 2013 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# This file contains the functions to manage host-only interfaces in the system

get_hostonly_interfaces() {
	echo -e `VBoxManage list hostonlyifs | grep '^Name' | sed 's/^Name\:[ \t]*//' | uniq | tr "\\n" ","`
}

get_instack_ifaces() {
	local instack_network=""
	local instack_networks=""
	local instack_iface=""
	local instack_ifaces=""
	for i in ${instack_master_ips}; do
		instack_network=$(echo "${i%.*}")
		instack_networks+="${instack_network} "
	done
	for ip in ${instack_networks}; do
		instack_iface=`VBoxManage list hostonlyifs | grep -B5 ${ip} | grep '^Name' | sed 's/^Name\:[ \t]*//' | uniq | tr "\\n" ","`
		instack_ifaces+="${instack_iface}"
	done
	echo ${instack_ifaces}
}

get_instack_name_ifaces() {
	local instack_ifaces=$(get_instack_ifaces)
	IFS=","
	set -- ${instack_ifaces}
	j=0
	for i in ${instack_ifaces}; do
		host_nic_name[${j}]=${i}
		j=$((j+1));
	done
	unset IFS
}

get_baremetal_name_ifaces() {
	local instack_ifaces=$(get_instack_ifaces)
	IFS=","
	set -- ${instack_ifaces}
	j=0
	for i in ${instack_ifaces}; do
		case ${j} in
			0)
				host_nic_name[${j}]=${i}
				j=$((j+1));
				;;
			1)
				# Do it one more time here.. so both nic1 and nic2 are set to vboxnet1.
				# nic0 will remain vboxnet0 and nic3 will be vboxnet2
				host_nic_name[${j}]=${i}
				j=$((j+1));
				host_nic_name[${j}]=${i}
				j=$((j+1));
				;;
			3)
				host_nic_name[${j}]=${i}
				j=$((j+1));
				;;
			*)
				;;
		esac
	done
	unset IFS
}

is_hostonly_interface_present() {
	name=${1}
	# String comparison with IF works different in Cygwin, probably due to encoding.
	# So, reduced Case is used. since it works the same way.
	# Default divider character change is mandatory for Cygwin.
	case "$(uname)" in
		CYGWIN*)
			OIFS=${IFS}
			IFS=","
			;;
		*)
			;;
	esac

	# Call VBoxManage directly instead of function, due to changed IFS
	local found_iface=(`VBoxManage list hostonlyifs | grep -E "Name: + $name\$" | awk '/Name/ { $1 = ""; print substr($0, 2) }'`)

	# Change default divider back
	case "$(uname)" in
		CYGWIN*)
			IFS=${OIFS}
			;;
		*)
			;;
	esac

	# Check that the list of interfaces contains the given interface
	if [[ "${found_iface}" == "${name}" ]]; then
		return 0
	else
		return 1
	fi
}

check_if_iface_settings_applied() {
	name=${1}
	ip=${2}
	mask=${3}
	echo "Verifying interface ${name} has IP ${ip} and mask ${mask} properly set."
	# Please leave 12 spaces in place - these are placed intentionally
	case "$(uname)" in
		CYGWIN*)
			OIFS=${IFS}
			IFS=","
			;;
		*)
			;;
	esac

	local new_name=(`VBoxManage list hostonlyifs | egrep -A9 "Name:            $name\$" | awk '/Name/ { $1 = ""; print substr($0, 2) }'`)
	case "$(uname)" in
		CYGWIN*)
			IFS=${OIFS}
			;;
		*)
			;;
	esac

	local new_ip=(`VBoxManage list hostonlyifs | egrep -A9 "Name:            $name\$" | awk '/IPAddress:/ {print $2}'`)
	local new_mask=(`VBoxManage list hostonlyifs | egrep -A9 "Name:            $name\$" | awk '/NetworkMask:/ {print $2}'`)
	local new_dhcp=(`VBoxManage list hostonlyifs | egrep -A9 "Name:            $name\$" | awk '/DHCP:/ {print $2}'`)
	# First verify if we checking correct interface
	if [[ "${name}" != "${new_name}" ]]; then
		echo "Checking ${name} but found settings for ${new_name}"
		return 1
	fi
	if [[ ${ip} != ${new_ip} ]]; then
		echo "New IP address ${ip} does not match the applied one ${new_ip}"
		return 1
	fi
	if [[ ${mask} != ${new_mask} ]]; then
		echo "New Net Mask ${mask} does not match the applied one ${new_mask}"
		return 1
	fi
	if [[ "Disabled" != ${new_dhcp} ]]; then
		echo "Failed to disable DHCP for network ${name}"
		return 1
	fi
	echo "OK."
	return 0
}

create_hostonly_interfaces() {
	# Creating host-only interface
	local ip=${1}
	echo "Creating host-only interface"
	local id=`VBoxManage hostonlyif create | sed "s/'/_/g" | cut -d "_" -f2 | sed "s/^_//" | sed "s/_$//"`
	# If it does not exist after creation, let's abort
	if ! is_hostonly_interface_present "${id}"; then
		echo "Fatal error. Interface ${id} does not exist after creation. Exiting"
		exit 1
	else
		echo "Interface" ${id} "was successfully created"
	fi

	# Disable DHCP
	echo "Disabling DHCP server on interface: ${name}..."
	# These magic 1 second sleeps around DHCP config are required under Windows/Cygwin
	# due to VBoxSvc COM server accepts next request before previous one is actually finished.
	sleep 1s
	VBoxManage dhcpserver remove --ifname "${name}" 2>/dev/null
	sleep 1s
	# Set up IP address and network mask
	echo "Configuring IP address ${ip} and network mask ${mask} on interface: ${name}..."
	VBoxManage hostonlyif ipconfig "${id}" --ip ${ip} --netmask ${mask}
	# Disable IPV6 on ctlplane (nic0)
	#sleep 1s
	#if [ "x${id}" = "xvboxnet0" ]; then
	#	sudo /sbin/sysctl -w net.ipv6.conf.vboxnet0.disable_ipv6=1
	#fi
	# Check what we have created actually.
	# Sometimes VBox occasionally fails to apply settings to the last IFace under Windows
	if !(check_if_iface_settings_applied "${id}" ${ip} ${mask}); then
		echo "Looks like VirtualBox failed to apply settings for interface ${name}"
		echo "Sometimes such error happens under Windows."
		echo "Please run launch.sh one more time."
		echo "If this error remains after several attempts, then something really went wrong."
		echo "Aborting."
		exit 1
	fi
}

# Checking that the interface has been removed
check_removed_iface() {
	local iface=${1}
	if is_hostonly_interface_present "${iface}"; then
		echo "Host-only interface \"${iface}\" was not removed. Aborting..."
		exit 1
	fi
}

delete_instack_ifaces() {
	# Only the interfaces that have IP addresses from the 'instack_master_ips'
	# variable in the config.sh scripts will be removed
	local instack_ifaces=$(get_instack_ifaces)
	if [ ! -z "${instack_ifaces}" ]; then
		check_running_vms "${instack_ifaces}"
		OIFS=${IFS}
		IFS=","
		for interface in ${instack_ifaces}; do
			IFS=${OIFS}
			echo "Deleting host-only interface: ${interface}..."
			VBoxManage hostonlyif remove "${interface}"
			check_removed_iface "${interface}"
		done
	fi
}

delete_all_hostonly_interfaces() {
	# All the hostonly interfaces will be removed
	local all_hostonly_interfaces=$(get_hostonly_interfaces)
	# Checking that the running virtual machines don't use removable host-only interfaces
	check_running_vms "${all_hostonly_interfaces}"
	OIFS=${IFS};IFS=",";list=(`VBoxManage list hostonlyifs | grep '^Name' | sed 's/^Name\:[ \t]*//' | uniq | tr "\\n" ","`);IFS=${OIFS}
	# Delete every single hostonly interface in the system
	for interface in "${list[@]}"; do
		echo "Deleting host-only interface: ${interface}..."
		VBoxManage hostonlyif remove "${interface}"
		check_removed_iface "${interface}"
	done
}
