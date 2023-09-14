param environmentName string
param location string = resourceGroup().location
param vnetId string
param logAnalyticsCustomerId string
param logAnalyticsSharedKey string
param appInsightsInstrumentationKey string
@description('Subnet resource ID for the Container App environment')
param infrastructureSubnetId string
// https://github.com/Azure/azure-rest-api-specs/blob/Microsoft.App-2022-01-01-preview/specification/app/resource-manager/Microsoft.App/preview/2022-01-01-preview/ManagedEnvironments.json

resource environment 'Microsoft.App/managedEnvironments@2023-05-02-preview' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    daprAIInstrumentationKey: appInsightsInstrumentationKey
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      // runtimeSubnetId: '${vnetId}/subnets/apps'
      internal: true
    }
  }
}
