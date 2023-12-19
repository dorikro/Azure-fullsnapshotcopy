# Azure Disk Snapshot Cross Region Copy Script

This script automates the process of creating snapshots of Azure disks and copying them to another region. It uses the Azure CLI to interact with Azure resources.

## Prerequisites

- Azure CLI installed and configured with appropriate permissions.
- Existing Azure disk that you want to create a snapshot of.

## Usage

1. Set the necessary variables at the beginning of the script. These include the project name, source and target resource groups, source disk name, and target location.
2. Run the script in your terminal

## Workflow
The script performs the following steps:

1. Creates an incremental snapshot of the source disk in the source resource group.
2. Creates a new snapshot in the target resource group, in the target location, using the source snapshot as the source.
3. Monitors the progress of the snapshot copy operation, waiting until it is complete.
4. Creates a new disk in the target resource group, in the target location, using the new snapshot as the source.
5. Creates a full snapshot of the new disk.
6. Asks the user if they want to delete the resources created during the script execution. If the user answers "yes", it deletes the incremental snapshot, the new snapshot, and the new disk.

## Error Handling
The script checks the exit status of each Azure CLI command. If any command fails, it prints an error message and exits with a status of 1.
