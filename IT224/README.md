# AzureLabs-VMs

This repo has scripts that will be used inside the Hyper-V server to create other VMs on Azure Labs

In the Azure Labs environment: 
1. pick a nested HyperV server. This will be the base VM.
2. import these selected scripts into the base Hyper-V.
3. Selectively run these scripts to generate other nested VMs, namey:
  a) IT224-DC1 - installed Server 2019
  b) IT224-DC2 - installed Server 2019
  c) IT224-MS1 - installed Server 2019
  d) IT224-Client - installed Windows 10
4. All the above mentioned (nested) VMs will be on the same network
5. All the above mentioned (nested) VMs will have access to Internet via a NAT situation with the base Hyper-V

