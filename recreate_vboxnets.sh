#!/bin/bash
VBoxManage hostonlyif create
VBoxManage dhcpserver remove --ifname vboxnet0
VBoxManage hostonlyif ipconfig vboxnet0 --ip 10.20.0.1 --netmask 255.255.255.0

VBoxManage hostonlyif create
VBoxManage dhcpserver remove --ifname vboxnet1
VBoxManage hostonlyif ipconfig vboxnet1 --ip 10.16.0.1 --netmask 255.255.255.0

VBoxManage hostonlyif create
VBoxManage dhcpserver remove --ifname vboxnet2
VBoxManage hostonlyif ipconfig vboxnet2 --ip 10.16.1.1 --netmask 255.255.255.0
