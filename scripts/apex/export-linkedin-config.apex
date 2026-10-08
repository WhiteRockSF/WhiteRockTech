LinkedInSecretStore.TokenBundle b = LinkedInSecretStore.getTokenBundle();
LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
Map<String, Object> out = new Map<String, Object>{
    'linkedInAdAccountUrn' => s.LinkedIn_Ad_Account_Urn__c,
    'linkedInApiVersion' => s.LinkedIn_API_Version__c,
    'hubSpotBatchSize' => s.HubSpot_Batch_Size__c,
    'useHubSpotNamedCredential' => s.Use_HubSpot_Named_Credential__c,
    'useLinkedInNamedCredential' => s.Use_LinkedIn_Named_Credential__c,
    'autoSyncEnabled' => s.Auto_Sync_Enabled__c,
    'autoSyncLookbackDays' => s.Auto_Sync_Lookback_Days__c,
    'defaultCampaignName' => s.Default_Campaign_Name__c,
    'defaultLinkedInCampaignId' => s.Default_LinkedIn_Campaign_Id__c,
    'defaultReportStart' => s.Default_Report_Start__c,
    'defaultReportEnd' => s.Default_Report_End__c,
    'scheduleHour' => s.Schedule_Hour__c,
    'hubSpotAccessToken' => s.HubSpot_Access_Token__c,
    'hasAccessToken' => String.isNotBlank(b.accessToken),
    'hasRefreshToken' => String.isNotBlank(b.refreshToken),
    'hasClientId' => String.isNotBlank(b.clientId),
    'hasClientSecret' => String.isNotBlank(b.clientSecret),
    'accessTokenExpiresAt' => b.accessTokenExpiresAt,
    'accessTokenLength' => b.accessToken != null ? b.accessToken.length() : 0
};
System.debug('LINKEDIN_CONFIG_EXPORT::' + JSON.serialize(out));
