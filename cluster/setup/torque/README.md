Scripts for setting up the Torque cluster environment on Azure should go in here.

1. head_setup.sh
2. node_setup.sh
3. user_setup.sh

`ip_hostname_cpu.list` a file that will be used to update `/etc/hosts`, `/var/spool/torque/server_priv/nodes` and loop through nodes if user/software updates needs to be done.

When setting up the storage in the `head_setup.sh` and `nodes_setup`scripts replace `AZURECLUSTERSTORE`, `AZURECLUSTERSTORE_USERNAME` and `AZURECLUSTERSTORE_PASSWORD` to what you have setup on the Azure dashboard.
