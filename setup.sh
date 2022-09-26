# user="USERNAME INPUT"
read -p "Enter user: " USERNAME
# PASSWORD = "PASSWORD INPUT"
read -p "Enter password: " PASSWORD
# RESOURCEGROUP = "RESOURCEGROUP INPUT"
read -p "Enter ResourceGroupName: " RESOURCEGROUP

read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

az group create \
  --location westus3 \
  --name $RESOURCEGROUP

# Script to create the load balancer and virtual machines for the MS Learn exercise

az network vnet create \
  --resource-group $RESOURCEGROUP \
  --name tbappvnet \
  --subnet-name tbappsubnet

az network nsg create \
  --resource-group $RESOURCEGROUP \
  --name tbappnsg

az network nsg rule create \
  --resource-group $RESOURCEGROUP \
  --name tbappvnetnsgrule \
  --nsg-name tbappnsg \
  --protocol tcp \
  --direction inbound \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --destination-address-prefix '*' \
  --destination-port-range 80 \
  --access allow \
  --priority 200

az network nsg rule create \
  --resource-group $RESOURCEGROUP \
  --name tbappvnetsshrule \
  --nsg-name tbappnsg \
  --protocol tcp \
  --direction inbound \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --destination-address-prefix '*' \
  --destination-port-range 22 \
  --access allow \
  --priority 300

az network vnet subnet update \
  --resource-group $RESOURCEGROUP \
  --vnet-name tbappvnet \
  --name tbappsubnet \
  --network-security-group tbappnsg

az network public-ip create \
  --resource-group $RESOURCEGROUP \
  --name tbappip \
  --sku Standard \
  --version IPv4

az network lb create \
  --resource-group $RESOURCEGROUP \
  --name tbapplb \
  --sku Standard \
  --public-ip-address tbappip \
  --public-ip-address-allocation Static \
  --frontend-ip-name tbappfrontend \
  --backend-pool-name tbapppool

az network lb probe create \
  --resource-group $RESOURCEGROUP \
  --lb-name tbapplb \
  --name tbapphealthprobe \
  --protocol Tcp \
  --interval 5 \
  --port 80

az network lb rule create \
  --resource-group $RESOURCEGROUP \
  --lb-name tbapplb \
  --name tbapprule \
  --protocol tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --frontend-ip-name tbappfrontend \
  --backend-pool-name tbapppool \
  --probe-name tbapphealthprobe

az network nsg create \
  --resource-group $RESOURCEGROUP \
  --name tbappnicvm1nsg

az network nsg rule create \
  --resource-group $RESOURCEGROUP \
  --name tbappvnetnsgvm1rule \
  --nsg-name tbappnicvm1nsg\
  --protocol tcp \
  --direction inbound \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --destination-address-prefix 'VirtualNetwork' \
  --destination-port-range 80 \
  --access allow \
  --priority 200

az network nsg rule create \
  --resource-group $RESOURCEGROUP \
  --name tbappvnetvm1sshrule \
  --nsg-name tbappnicvm1nsg\
  --protocol tcp \
  --direction inbound \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --destination-address-prefix 'VirtualNetwork' \
  --destination-port-range 22 \
  --access allow \
  --priority 100

az network nic create \
  --resource-group $RESOURCEGROUP \
  --name nicvm1 \
  --vnet-name tbappvnet \
  --subnet tbappsubnet \
  --network-security-group tbappnicvm1nsg \
  --lb-name tbapplb \
  --lb-address-pools tbapppool

az network nsg create \
  --resource-group $RESOURCEGROUP \
  --name tbappnicvm2nsg

az network nsg rule create \
  --resource-group $RESOURCEGROUP \
  --name tbappvnetnsgvm2rule \
  --nsg-name tbappnicvm2nsg\
  --protocol tcp \
  --direction inbound \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --destination-address-prefix 'VirtualNetwork' \
  --destination-port-range 80 \
  --access allow \
  --priority 200

az network nsg rule create \
  --resource-group $RESOURCEGROUP \
  --name tbappvnetvm2sshrule \
  --nsg-name tbappnicvm2nsg\
  --protocol tcp \
  --direction inbound \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --destination-address-prefix 'VirtualNetwork' \
  --destination-port-range 22 \
  --access allow \
  --priority 100

az network nic create \
  --resource-group $RESOURCEGROUP \
  --name nicvm2 \
  --vnet-name tbappvnet \
  --subnet tbappsubnet \
  --network-security-group tbappnicvm2nsg \
  --lb-name tbapplb \
  --lb-address-pools tbapppool

az vm create \
  --resource-group $RESOURCEGROUP \
  --name tbappvm1 \
  --nics nicvm1 \
  --admin-username azureuser \
  --admin-password $PASSWORD \
  --image UbuntuLTS \
  --public-ip-address "" 

az vm extension set \
  --publisher Microsoft.Azure.Extensions \
  --version 2.0 \
  --name CustomScript \
  --vm-name tbappvm1 \
  --resource-group $RESOURCEGROUP \
  --settings '{"commandToExecute":"apt-get -y update && apt-get -y install nginx && hostname > /var/www/html/index.html"}'

az vm create \
  --resource-group $RESOURCEGROUP \
  --name tbappvm2 \
  --nics nicvm2 \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --image UbuntuLTS \
  --public-ip-address ""

az vm extension set \
  --publisher Microsoft.Azure.Extensions \
  --version 2.0 \
  --name CustomScript \
  --vm-name tbappvm2 \
  --resource-group $RESOURCEGROUP \
  --settings '{"commandToExecute":"apt-get -y update && apt-get -y install nginx && hostname > /var/www/html/index.html"}'

## ## ## ## ## ##
# Script to reconfigure the lab environment and introduce problems that the student diagnoses and corrects.
# POINT HEALTH PROBE AT PORT 85 IN BACKEND POOL

az network lb probe update \
  --resource-group $RESOURCEGROUP \
  --lb-name tbapplb \
  --name tbapphealthprobe \
  --protocol Tcp \
  --port 85

# STOP tbappvm2
az vm stop \
  --resource-group $RESOURCEGROUP \
  --name tbappvm2

# SET NSG FOR SUBNET WITH PORT 80 MISSING
az network nsg rule delete \
  --resource-group $RESOURCEGROUP \
  --name tbappvnetnsgrule \
  --nsg-name tbappnsg

# SET NSG FOR tbappvm2 WITH DENY ALL
az network nsg rule create \
  --resource-group $RESOURCEGROUP \
  --name tbappvnetnsgrulevm2denyall \
  --nsg-name tbappnicvm2nsg \
  --protocol tcp \
  --direction inbound \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --destination-address-prefix '*' \
  --destination-port-range '*' \
  --access deny \
  --priority 110
