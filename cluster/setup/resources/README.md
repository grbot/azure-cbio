Scripts for setting up Azure resources should go here.

How to run

1. Setup an Azure-CLI docker container on your local machine or use any other way to gain access to
an Azure CLI.

2. Start the Azure-CLI (just an example using docker and doing mounts)
  ```bash
  docker run -v /home/user:/home/user -it microsoft/azure-cli
  ```

3. Login to Azure, select the right subscription, set the config mode arm, create the resource group if not existing already then.
```
azure login
```

4. Some bash variables (example)
```bash
CLUSTER="AZURE_CLUSTER"
USER="AZURE_USER"
JSONDEF="azuredeploy-prod.json"
PASSWD="AZURE_USER"
DNSNAME="AZURE_DNS"
TORQUELIST="ip_hostname_cpu.h3a-prod.list"
```

5. Then run

  ```bash
  DEPLOYMENT=${CLUSTER}"Deployment"
  azure group deployment create -g ${CLUSTER} -f ${JSONDEF} -m Incremental -n ${DEPLOYMENT}
  ```
   - For now resource parameter settings are set in ${JSONDEF} and not in a separate parameter file. This is the only way that I'm able to provide the admin password from the commandline.

6.  Once set up (took about 10 minutes for setting up the dev cluster, a head and two compute nodes), ssh into the head

  ```bash
  ssh ${DNSNAME}.westeurope.cloudapp.azure.com
  ```

7. Clone the GitHub repos.

  ```git clone https://github.com/grbot/azure-cbio```

8. Start running the Torque setup.

  ``` sh
  # setup head node
  ./head_setup.sh ${USER} ${PASSWD} ${TORQUELIST} 2>&1 | less
  # setup compute nodes
  ./node_setup.sh ${USER} ${PASSWD} ${TORQUELIST} 2>&1 | less
  # setup user
  ./user_setup.sh ${USER} ${PASSWD} ${TORQUELIST} test03  2>&1 | less
  ```

9. Managing nodes in CLI. Also look at info [here](https://docs.microsoft.com/en-us/azure/virtual-machines/azure-cli-arm-commands)
 * Start vms
    ```
    for i in `azure vm list -g ${CLUSTER} | awk '{print $3" "$8}' | grep "Standard" | awk '{print $1}'`
    do
    azure vm start ${CLUSTER} $i
    done
    ```  
  * Show info
    ```
    for i in `azure vm list -g ${CLUSTER} | awk '{print $3" "$8}' | grep "Standard" | awk '{print $1}'`
    do
    azure vm show ${CLUSTER} $i
    done
    ```
  * Stop
    ```
    for i in `azure vm list -g ${CLUSTER} | awk '{print $3" "$8}' | grep "Standard" | awk '{print $1}'`
    do
    azure vm stop ${CLUSTER} $i
    done
    ```  
  * Deallocate
    ```
    for i in `azure vm list -g ${CLUSTER} | awk '{print $3" "$8}' | grep "Standard" | awk '{print $1}'`
    do
    echo "deallocating" $i
    azure vm deallocate ${CLUSTER} $i
    done
    ```  
