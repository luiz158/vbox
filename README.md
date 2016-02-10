VirtualBox scripts for provisionning an OSP tripleo virtual infra.
==========================

Requirements
------------

- VirtualBox with VirtualBox Extension Pack
- procps
- expect
- Cygwin for Windows host PC
- Enable VT-x/AMD-V acceleration option on your hardware for 64-bits guests
- socat

Run
---

In order to successfully run Mirantis OpenStack under VirtualBox, you need to:
- download the official release (.iso) and place it under 'iso/' directory
- run "./launch.sh" (or "./launch\_8GB.sh", "./launch\_16GB.sh" or "./launch\_64GB.sh" according to your system resources).
  It will automatically pick up the iso and spin up master node and slave nodes

If there are any errors, the script will report them and abort.

If you want to change settings (number of OpenStack nodes, CPU, RAM, HDD), please refer to "config.sh".

To shutdown VMs and clean environment just run "./clean.sh"
