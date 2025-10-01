// ===============================================
// Bicep template for LAB565 - Microsoft 365 Copilot Agents
// Creates: Storage Account, AI Search, Search Index, OpenAI Service, Text Embedding Model
// ===============================================

@description('Lab user object ID for role assignments')
param labUserObjectId string

@description('The name prefix for all resources')
param resourcePrefix string = 'lab565'

@description('The location where all resources will be deployed')
param location string = 'eastus'

@description('Storage account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS'])
param storageAccountSku string = 'Standard_RAGRS'

@description('AI Search service SKU')
@allowed(['basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param searchServiceSku string = 'standard'

@description('OpenAI service SKU')
@allowed(['S0'])
param openAiSku string = 'S0'

@description('Text embedding model name')
@allowed(['text-embedding-ada-002', 'text-embedding-3-small', 'text-embedding-3-large'])
param embeddingModelName string = 'text-embedding-ada-002'

@description('Text embedding model version')
param embeddingModelVersion string = '2'

@description('Embedding model deployment capacity')
@minValue(1)
@maxValue(120)
param embeddingModelCapacity int = 30

// Variables for resource naming and configuration
var uniqueSuffix = uniqueString(resourceGroup().id)
var resourceNames = {
  storageAccount: '${resourcePrefix}st${uniqueSuffix}'
  searchService: '${resourcePrefix}-search-${uniqueSuffix}'
  searchIndex: '${resourcePrefix}-index'
  openAiService: '${resourcePrefix}-openai-${uniqueSuffix}'
  embeddingDeployment: 'text-embedding'
}

// Ensure storage account name meets requirements (3-24 chars, lowercase alphanumeric)
var storageAccountName = length(resourceNames.storageAccount) > 24 ? substring(resourceNames.storageAccount, 0, 24) : resourceNames.storageAccount

// ===============================================
// AZURE STORAGE ACCOUNT
// ===============================================

@description('Azure Storage Account for document storage and processing')
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
  }
}

// Create blob service for the storage account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: true
  }
}

// Create container for resumes
resource resumesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'resumes'
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'Document storage for AI processing'
    }
  }
}

// ===============================================
// AZURE AI SEARCH SERVICE
// ===============================================

@description('Azure AI Search service for vector search and document indexing')
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: resourceNames.searchService
  location: location
  sku: {
    name: searchServiceSku
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
    networkRuleSet: {
      ipRules: []
    }
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    semanticSearch: 'free'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// ===============================================
// AZURE OPENAI SERVICE
// ===============================================

@description('Azure OpenAI service for AI models and embeddings')
resource openAiService 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: resourceNames.openAiService
  location: location
  sku: {
    name: openAiSku
  }
  kind: 'OpenAI'
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
    customSubDomainName: resourceNames.openAiService
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// ===============================================
// TEXT EMBEDDING MODEL DEPLOYMENT
// ===============================================

@description('Text embedding model deployment for vector generation')
resource embeddingModelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAiService
  name: resourceNames.embeddingDeployment
  properties: {
    model: {
      format: 'OpenAI'
      name: embeddingModelName
      version: embeddingModelVersion
    }
    raiPolicyName: 'Microsoft.Default'
  }
  sku: {
    name: 'Standard'
    capacity: embeddingModelCapacity
  }
}

// ===============================================
// SECURITY ROLE ASSIGNMENTS
// ===============================================

// Cognitive Services User for Search Service
resource CogsUserSPRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, searchService.name, 'sp-cogs-user', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  properties: {
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  }
}

// OpenAI host role assignment (scoped to the OpenAI resource group's scope)
resource openAiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, searchService.name, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  properties: {
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}

// Storage Blob Data Reader role (scoped to the storage resource group)
resource storageReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, searchService.name, '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
  properties: {
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
  }
}

// Storage Blob Data Contributor role (scoped to the storage resource group)
resource storageContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, searchService.name, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  properties: {
    principalId: searchService.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  }
}

// ===============================================
// LAB USER ROLE ASSIGNMENTS
// ===============================================

// Contributor at RG scope
resource userRgContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, labUserObjectId, 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  scope: resourceGroup()
  properties: {
    principalId: labUserObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  }
}

// Storage Blob Data Contributor role for lab user
resource userStorageContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, storageAccount.name, labUserObjectId, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: storageAccount
  properties: {
    principalId: labUserObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  }
}

// Search Service Contributor role for lab user
resource userSearchContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, searchService.name, labUserObjectId, '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
  scope: searchService
  properties: {
    principalId: labUserObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
  }
}

// Search Index Data Reader role for lab user
resource userSearchIndexContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, searchService.name, labUserObjectId, '1407120a-92aa-4202-b7e9-c0e197c71c8f')
  scope: searchService
  properties: {
    principalId: labUserObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f')
  }
}

// Cognitive Services Contributor role for lab user
resource userOpenAiContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, openAiService.name, labUserObjectId, '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
  scope: openAiService
  properties: {
    principalId: labUserObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
  }
}

// Cognitive Services OpenAI User role for lab user
resource userOpenAiUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, openAiService.name, labUserObjectId, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  scope: openAiService
  properties: {
    principalId: labUserObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  }
}

// Cognitive Services User for Lab User
resource CogsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, labUserObjectId, 'user-cogs-user', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  scope: searchService
  properties: {
    principalId: labUserObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  }
}

// ===============================================
// OUTPUTS
// ===============================================

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Storage account primary endpoint')
output storageAccountPrimaryEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('Resumes container name')
output resumesContainerName string = resumesContainer.name

@description('AI Search service name')
output searchServiceName string = searchService.name

@description('AI Search service endpoint')
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'

@description('OpenAI service name')
output openAiServiceName string = openAiService.name

@description('OpenAI service endpoint')
output openAiServiceEndpoint string = openAiService.properties.endpoint

@description('Text embedding model deployment name')
output embeddingDeploymentName string = embeddingModelDeployment.name

@description('Resource group location')
output resourceGroupLocation string = location

@description('Unique suffix used for resource naming')
output uniqueSuffix string = uniqueSuffix

@description('Lab user object ID')
output labUserObjectId string = labUserObjectId

// ===============================================
// USAGE NOTES
// ===============================================
/*

DEPLOYMENT COMMAND:
# Deploy to an existing resource group
az deployment group create --resource-group <your-existing-rg-name> --template-file LAB565.bicep --parameters resourcePrefix=<your-prefix>

# Example with specific values:
az deployment group create --resource-group rg-copilot-lab --template-file LAB565.bicep --parameters resourcePrefix=mylab565

# To deploy with custom parameters:
az deployment group create --resource-group <your-existing-rg-name> --template-file LAB565.bicep --parameters resourcePrefix=<your-prefix> storageAccountSku=Standard_GRS searchServiceSku=standard embeddingModelName=text-embedding-3-small

*/
