#!/bin/bash

# Variables
projectName="[projectName]"
sourceResourceGroup="[sourceResourceGroup]"
sourceDiskName="[sourceDiskName]"
sourceDiskSize=$(az disk show --resource-group $sourceResourceGroup --name $sourceDiskName --query diskSizeGb --output tsv)
targetResourceGroup="[targetResourceGroup]"
targetLocation="[targetLocation]"
timestamp=$(date +%Y%m%d%H%M%S)
# ANSI escape code to set the text color to green
green='\033[0;32m'
# ANSI escape code to reset the text color to the default
reset='\033[0m'

echo -e "${green}Getting the source volume ID...${reset}"
sourceVolumeId=$(az disk show --name $sourceDiskName --resource-group $sourceResourceGroup --query id -o tsv)
if [ $? -ne 0 ]; then
  echo "Failed to get the source volume ID."
  exit 1
fi

echo -e "${green}Creating an incremental snapshot from a volume...${reset}"
incrementalSnapshotName="$projectName-incrementalSnapshot-$timestamp"
az snapshot create \
  --resource-group $sourceResourceGroup \
  --name $incrementalSnapshotName \
  --source $sourceVolumeId \
  --incremental \
  --sku Standard_ZRS
if [ $? -ne 0 ]; then
  echo "Failed to create an incremental snapshot from the volume."
  exit 1
fi

echo -e "${green}Getting the source snapshot ID...${reset}"
sourceSnapshotId=$(az snapshot show --name $incrementalSnapshotName --resource-group $sourceResourceGroup --query id -o tsv)
if [ $? -ne 0 ]; then
  echo "Failed to get the source snapshot ID."
  exit 1
fi

echo -e "${green}Creating a new snapshot in the target region using the source snapshot...${reset}"
newSnapshotName="$projectName-otherregion-$timestamp"
az snapshot create \
  --resource-group $targetResourceGroup \
  --name $newSnapshotName \
  --location $targetLocation \
  --source $sourceSnapshotId \
  --incremental \
  --copy-start
if [ $? -ne 0 ]; then
  echo "Failed to create a new snapshot in the target region using the source snapshot."
  exit 1
fi

echo -e "${green}Waiting for the snapshot to be ready...${reset}"
while true; do
  completionPercent=$(az snapshot show --name $newSnapshotName --resource-group $targetResourceGroup --query completionPercent -o tsv)
  echo -e "\033[0;32mSnapshot copy progress: $completionPercent%\033[0m"
  if (( $(echo "$completionPercent >= 100" |bc -l) )); then
    break
  else
    sleep 10
  fi
done

echo -e "${green}Creating a new disk from the snapshot...${reset}"
newDiskName="$projectName-newDisk-$timestamp"
az disk create \
  --resource-group $targetResourceGroup \
  --name $newDiskName \
  --source $newSnapshotName \
  --location $targetLocation \
  --sku Premium_LRS \
  --size-gb $sourceDiskSize
if [ $? -ne 0 ]; then
  echo "Failed to create a new disk from the snapshot."
  exit 1
fi

echo -e "${green}Creating a full snapshot from the new disk...${reset}"
fullSnapshotName="$projectName-fullSnapshot-$timestamp"
az snapshot create \
  --resource-group $targetResourceGroup \
  --name $fullSnapshotName \
  --source $newDiskName
if [ $? -ne 0 ]; then
  echo "Failed to create a full snapshot from the new disk."
  exit 1
fi

echo -e "\033[5m\033[1m********** Do you want to delete the resources? (yes/no) **********\033[0m"
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo -e "${green}Deleting the incremental snapshot...${reset}"
    az snapshot delete \
      --resource-group $sourceResourceGroup \
      --name $incrementalSnapshotName
    if [ $? -ne 0 ]; then
      echo "Failed to delete the incremental snapshot."
      exit 1
    fi

    echo -e "${green}Deleting the new snapshot...${reset}"
    az snapshot delete \
      --resource-group $targetResourceGroup \
      --name $newSnapshotName
    if [ $? -ne 0 ]; then
      echo "Failed to delete the new snapshot."
      exit 1
    fi

    echo -e "${green}Deleting the new disk...${reset}"
    az disk delete \
      --resource-group $targetResourceGroup \
      --name $newDiskName \
      --yes
    if [ $? -ne 0 ]; then
      echo "Failed to delete the new disk."
      exit 1
    fi
else
    echo "Resources will not be deleted."
fi
