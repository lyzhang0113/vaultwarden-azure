targetScope = 'resourceGroup'

@description('Azure region for the future Vaultwarden deployment.')
param location string = resourceGroup().location

@description('Base name used for derived resource names.')
@minLength(3)
@maxLength(24)
param appName string = 'vaultwarden'

@description('Pinned Vaultwarden image tag, for example 1.35.4-alpine.')
param containerImageTag string

@description('Container Apps CPU allocation in cores. Task 4 currently supports the paired 0.5 CPU / 1 GiB shape only.')
@allowed([
  '0.5'
])
param containerCpu string = '0.5'

@description('Container Apps memory allocation in GiB. Task 4 currently supports the paired 0.5 CPU / 1 GiB shape only.')
@allowed([
  '1'
])
param containerMemoryGiB string = '1'

@description('Storage account SKU reserved for the Azure Files data share.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
])
param storageAccountSku string = 'Standard_LRS'

@description('Address space assigned to the virtual network used for Container Apps infrastructure and private PostgreSQL connectivity.')
param vnetAddressPrefix string = '10.42.0.0/16'

@description('Subnet reserved for the Container Apps managed environment infrastructure.')
param containerAppsSubnetPrefix string = '10.42.0.0/23'

@description('Delegated subnet reserved for the future private PostgreSQL flexible server.')
param postgresSubnetPrefix string = '10.42.2.0/28'

@description('Delegated subnet reserved for the deployment script container group that provisions the Vaultwarden database role.')
param deploymentScriptSubnetPrefix string = '10.42.2.16/28'

@description('PostgreSQL flexible server administrator username.')
param postgresAdminUsername string = 'vwadmin'

@description('PostgreSQL flexible server version.')
@allowed([
  '14'
  '15'
  '16'
  '17'
])
param postgresVersion string = '16'

@description('Burstable SKU used for the private PostgreSQL flexible server.')
param postgresSkuName string = 'Standard_B1ms'

@description('Initial PostgreSQL storage size in GiB.')
@allowed([
  32
  64
  128
])
param postgresStorageSizeGiB int = 32

@secure()
@description('PostgreSQL flexible server administrator password.')
param postgresAdminPassword string

@description('Vaultwarden PostgreSQL database name.')
param databaseName string = 'vaultwarden'

@description('Dedicated Vaultwarden PostgreSQL login used by the application.')
param vaultwardenDbUsername string = 'vaultwarden'

@secure()
@description('Password for the dedicated Vaultwarden PostgreSQL login.')
param vaultwardenDbPassword string

@secure()
@description('Vaultwarden admin token for the application deployment.')
param adminToken string

@description('Minimum replica count for the future Vaultwarden container app. Keep this less than or equal to maxReplicas.')
@minValue(1)
@maxValue(10)
param minReplicas int = 1

@description('Maximum replica count for the future Vaultwarden container app. Keep this greater than or equal to minReplicas.')
@minValue(1)
@maxValue(10)
param maxReplicas int = 2

var nameSuffix = take(uniqueString(resourceGroup().id, appName), 6)
var resourcePrefix = toLower(appName)
var storageNamePrefix = take(replace(resourcePrefix, '-', ''), 16)
var storageAccountName = 'st${storageNamePrefix}${nameSuffix}'
var fileShareName = 'vw-data'
var logAnalyticsWorkspaceName = '${resourcePrefix}-log-${nameSuffix}'
var managedEnvironmentName = '${resourcePrefix}-cae-${nameSuffix}'
var managedEnvironmentStorageName = 'azurefiles'
var containerAppName = '${resourcePrefix}-ca-${nameSuffix}'
var virtualNetworkName = '${resourcePrefix}-vnet-${nameSuffix}'
var containerAppsSubnetName = 'snet-cae'
var postgresSubnetName = 'snet-postgres'
var deploymentScriptSubnetName = 'snet-deploy'
var postgresServerName = '${resourcePrefix}-pg-${nameSuffix}'
var postgresPrivateDnsZoneName = '${resourcePrefix}-db-${nameSuffix}.postgres.database.azure.com'
var containerImage = 'docker.io/vaultwarden/server:${containerImageTag}'
var databaseHostName = postgresServer.properties.fullyQualifiedDomainName
var deploymentScriptName = '${resourcePrefix}-db-user-${nameSuffix}'
var deploymentScriptContainerGroupName = take('${resourcePrefix}-db-user-${nameSuffix}', 63)
var deploymentScriptIdentityName = '${resourcePrefix}-db-user-id-${nameSuffix}'
var databaseUrlSecretName = 'database-url'
var adminTokenSecretName = 'admin-token'
var containerAppsSubnetResourceId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, containerAppsSubnetName)
var postgresSubnetResourceId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, postgresSubnetName)
var deploymentScriptSubnetResourceId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, deploymentScriptSubnetName)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageAccountSku
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }

  resource fileService 'fileServices@2023-05-01' = {
    name: 'default'

    resource dataShare 'shares@2023-05-01' = {
      name: fileShareName
    }
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: containerAppsSubnetName
        properties: {
          addressPrefix: containerAppsSubnetPrefix
          delegations: [
            {
              name: 'container-apps'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: postgresSubnetName
        properties: {
          addressPrefix: postgresSubnetPrefix
          delegations: [
            {
              name: 'postgres-flexible-server'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: deploymentScriptSubnetName
        properties: {
          addressPrefix: deploymentScriptSubnetPrefix
          delegations: [
            {
              name: 'container-instance'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
    ]
  }
}

resource postgresPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: postgresPrivateDnsZoneName
  location: 'global'
}

resource postgresPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: postgresPrivateDnsZone
  name: '${virtualNetworkName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: postgresServerName
  location: location
  sku: {
    name: postgresSkuName
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: postgresAdminUsername
    administratorLoginPassword: postgresAdminPassword
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
    network: {
      delegatedSubnetResourceId: postgresSubnetResourceId
      privateDnsZoneArmResourceId: postgresPrivateDnsZone.id
    }
    storage: {
      storageSizeGB: postgresStorageSizeGiB
    }
    version: postgresVersion
  }
  dependsOn: [
    virtualNetwork
    postgresPrivateDnsZoneLink
  ]
}

resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: deploymentScriptIdentityName
  location: location
}

resource storageFileDataPrivilegedContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
  scope: tenant()
}

resource deploymentScriptStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, deploymentScriptIdentity.id, storageFileDataPrivilegedContributor.id)
  properties: {
    principalId: deploymentScriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageFileDataPrivilegedContributor.id
  }
}

resource provisionVaultwardenDbUser 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: deploymentScriptName
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.59.0'
    cleanupPreference: 'OnSuccess'
    containerSettings: {
      containerGroupName: deploymentScriptContainerGroupName
      subnetIds: [
        {
          id: deploymentScriptSubnetResourceId
        }
      ]
    }
    storageAccountSettings: {
      storageAccountName: storageAccount.name
      storageAccountKey: storageAccount.listKeys().keys[0].value
    }
    environmentVariables: [
      {
        name: 'PGHOST'
        value: databaseHostName
      }
      {
        name: 'PGDATABASE'
        value: databaseName
      }
      {
        name: 'PGUSER'
        value: postgresAdminUsername
      }
      {
        name: 'APP_DB_USER'
        value: vaultwardenDbUsername
      }
      {
        name: 'PGPASSWORD'
        secureValue: postgresAdminPassword
      }
      {
        name: 'APP_DB_PASSWORD'
        secureValue: vaultwardenDbPassword
      }
    ]
    forceUpdateTag: guid(resourceGroup().id, appName, databaseName, vaultwardenDbUsername)
    retentionInterval: 'P1D'
    scriptContent: loadTextContent('scripts/provision-vaultwarden-db-user.sh')
    timeout: 'PT30M'
  }
  dependsOn: [
    deploymentScriptStorageRoleAssignment
    postgresDatabase
    postgresPrivateDnsZoneLink
    virtualNetwork
  ]
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: managedEnvironmentName
  location: location
  sku: {
    name: 'Consumption'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: containerAppsSubnetResourceId
    }
  }
  dependsOn: [
    virtualNetwork
  ]

  resource managedEnvironmentStorage 'storages@2024-03-01' = {
    name: managedEnvironmentStorageName
    properties: {
      azureFile: {
        accessMode: 'ReadWrite'
        accountKey: storageAccount.listKeys().keys[0].value
        accountName: storageAccount.name
        shareName: fileShareName
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  dependsOn: [
    provisionVaultwardenDbUser
  ]
  properties: {
    environmentId: managedEnvironment.id
    configuration: {
      ingress: {
        allowInsecure: false
        external: true
        targetPort: 80
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      secrets: [
        {
          name: adminTokenSecretName
          value: adminToken
        }
        {
          name: databaseUrlSecretName
          value: 'postgresql://${vaultwardenDbUsername}:${uriComponent(vaultwardenDbPassword)}@${databaseHostName}:5432/${databaseName}'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'vaultwarden'
          image: containerImage
          env: [
            {
              name: 'ADMIN_TOKEN'
              secretRef: adminTokenSecretName
            }
            {
              name: 'DATABASE_URL'
              secretRef: databaseUrlSecretName
            }
            {
              name: 'ENABLE_WEBSOCKET'
              value: 'true'
            }
          ]
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/alive'
                port: 80
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 18
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/alive'
                port: 80
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/alive'
                port: 80
              }
              initialDelaySeconds: 10
              periodSeconds: 15
              failureThreshold: 3
            }
          ]
          resources: {
            cpu: json(containerCpu)
            memory: '${containerMemoryGiB}Gi'
          }
          volumeMounts: [
            {
              volumeName: 'vaultwarden-data'
              mountPath: '/data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
      volumes: [
        {
          name: 'vaultwarden-data'
          storageName: managedEnvironmentStorageName
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

output deploymentSkeleton object = {
  location: location
  appName: appName
  imageTag: containerImageTag
  containerSizing: {
    cpu: containerCpu
    memoryGiB: containerMemoryGiB
  }
  storageSku: storageAccountSku
  network: {
    vnetAddressPrefix: vnetAddressPrefix
    containerAppsSubnetPrefix: containerAppsSubnetPrefix
    deploymentScriptSubnetPrefix: deploymentScriptSubnetPrefix
    postgresSubnetPrefix: postgresSubnetPrefix
    privateDnsZoneName: postgresPrivateDnsZoneName
  }
  postgres: {
    adminUsername: postgresAdminUsername
    databaseName: databaseName
    hostName: databaseHostName
    skuName: postgresSkuName
    storageSizeGiB: postgresStorageSizeGiB
    vaultwardenDbUsername: vaultwardenDbUsername
    version: postgresVersion
  }
  replicas: {
    min: minReplicas
    max: maxReplicas
  }
  containerApp: {
    name: containerAppName
    image: containerImage
  }
}

output derivedNames object = {
  logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  storageAccountName: storageAccountName
  fileShareName: fileShareName
  managedEnvironmentName: managedEnvironmentName
  managedEnvironmentStorageName: managedEnvironmentStorageName
  containerAppName: containerAppName
  virtualNetworkName: virtualNetworkName
  containerAppsSubnetName: containerAppsSubnetName
  deploymentScriptSubnetName: deploymentScriptSubnetName
  postgresSubnetName: postgresSubnetName
  postgresPrivateDnsZoneName: postgresPrivateDnsZoneName
  postgresServerName: postgresServerName
}
