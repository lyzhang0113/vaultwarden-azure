using '../main.bicep'

// Non-secret production defaults only. Supply secure inputs locally via environment variables.
param adminToken = readEnvironmentVariable('ADMIN_TOKEN')
param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD')
param vaultwardenDbPassword = readEnvironmentVariable('VAULTWARDEN_DB_PASSWORD')

param location = 'eastasia'
param appName = 'vaultwarden-prod'
param containerImageTag = '1.35.4-alpine'
param containerCpu = '0.5'
param containerMemoryGiB = '1'
param storageAccountSku = 'Standard_LRS'
param vnetAddressPrefix = '10.42.0.0/16'
param containerAppsSubnetPrefix = '10.42.0.0/23'
param postgresSubnetPrefix = '10.42.2.0/28'
param postgresAdminUsername = 'vwadmin'
param postgresVersion = '16'
param postgresSkuName = 'Standard_B1ms'
param postgresStorageSizeGiB = 32
param databaseName = 'vaultwarden'
param vaultwardenDbUsername = 'vaultwarden'
param minReplicas = 1
param maxReplicas = 2
