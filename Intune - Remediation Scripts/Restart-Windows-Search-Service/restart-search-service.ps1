<#
Script: restart-search-service.ps1
Description: Restarts Windows Search service
Hint: This is a community script. There is no guarantee for this. Please check thoroughly before running.
Version 1.0: Init
Run as: System
Context: 64 Bit
#> 

$servicename = "WSearch"

Restart-Service -Name $servicename -Force