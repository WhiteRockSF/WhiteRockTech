public with sharing class LinkedInIntegrationConfig {
    public static LinkedIn_Integration_Settings__c getOrgSettings() {
        LinkedIn_Integration_Settings__c s = LinkedIn_Integration_Settings__c.getOrgDefaults();
        if (s == null || s.Id == null) {
            s = new LinkedIn_Integration_Settings__c();
            s.SetupOwnerId = UserInfo.getOrganizationId();
        }
        return s;
    }

    public static LinkedIn_HubSpot_Config__mdt getHubSpotConfig() {
        LinkedIn_HubSpot_Config__mdt cfg = LinkedIn_HubSpot_Config__mdt.getInstance('Default');
        if (cfg == null) {
            throw new LinkedInAdMetricsException('LinkedIn HubSpot Config metadata record "Default" is missing.');
        }
        return cfg;
    }

    public static LinkedInIntegrationSettingsDto loadDto() {
        LinkedIn_Integration_Settings__c s = getOrgSettings();
        LinkedIn_HubSpot_Config__mdt hs = getHubSpotConfig();
        LinkedInIntegrationSettingsDto dto = new LinkedInIntegrationSettingsDto();
        dto.linkedInAccessToken = resolveLinkedInAccessTokenForUi(s);
        dto.linkedInRefreshToken = null; // never echo secrets back to UI
        dto.linkedInClientId = null;
        dto.linkedInClientSecret = null;
        dto.linkedInRefreshConfigured = LinkedInSecretStore.hasRefreshCredentials();
        dto.linkedInAdAccountUrn = s.LinkedIn_Ad_Account_Urn__c;
        dto.linkedInApiVersion = String.isNotBlank(s.LinkedIn_API_Version__c) ? s.LinkedIn_API_Version__c : '202607';
        dto.hubSpotAccessToken = s.HubSpot_Access_Token__c;
        dto.useHubSpotNamedCredential = s.Use_HubSpot_Named_Credential__c != false;
        dto.useLinkedInNamedCredential = s.Use_LinkedIn_Named_Credential__c == true;
        dto.hubSpotBatchSize = s.HubSpot_Batch_Size__c != null ? s.HubSpot_Batch_Size__c : 50;
        dto.defaultLinkedInCampaignId = s.Default_LinkedIn_Campaign_Id__c;
        dto.defaultCampaignName = s.Default_Campaign_Name__c;
        dto.defaultReportStart = s.Default_Report_Start__c != null
            ? String.valueOf(s.Default_Report_Start__c)
            : null;
        dto.defaultReportEnd = s.Default_Report_End__c != null
            ? String.valueOf(s.Default_Report_End__c)
            : null;
        dto.hubSpotTargetType = hs.HubSpot_Target_Type__c;
        dto.hubSpotCustomObjectTypeId = hs.HubSpot_Custom_Object_Type_Id__c;
        dto.propImpressions = hs.HubSpot_Property_Impressions__c;
        dto.propClicks = hs.HubSpot_Property_Clicks__c;
        dto.propConversions = hs.HubSpot_Property_Conversions__c;
        dto.propCampaign = hs.HubSpot_Property_Campaign__c;
        dto.autoSyncEnabled = s.Auto_Sync_Enabled__c == true;
        dto.autoSyncLookbackDays = s.Auto_Sync_Lookback_Days__c != null ? s.Auto_Sync_Lookback_Days__c : 30;
        dto.scheduleHour = s.Schedule_Hour__c != null ? s.Schedule_Hour__c : 6;
        try {
            LinkedInAdSyncScheduler.ScheduleInfo sched = LinkedInAdSyncScheduler.getScheduleInfo();
            dto.scheduleJobActive = sched.scheduled;
            dto.scheduleNextFire = sched.nextFireTime != null ? sched.nextFireTime.format() : null;
            dto.scheduleState = sched.state;
            dto.scheduleCampaignSummary = sched.campaignSummary;
            if (sched.scheduleHour != null) {
                dto.scheduleHour = sched.scheduleHour;
            }
        } catch (Exception e) {
            dto.scheduleJobActive = false;
        }
        return dto;
    }

    /**
     * Only overwrite fields when the DTO sends a non-blank / non-null value.
     * Prevents Test LinkedIn (or empty LWC payload) from wiping URN / Campaign Id.
     */
    public static void saveOrgSettings(LinkedInIntegrationSettingsDto dto) {
        if (dto == null) {
            throw new LinkedInAdMetricsException('Settings are required.');
        }
        LinkedIn_Integration_Settings__c s = getOrgSettings();

        Boolean storeSecure =
            dto.useLinkedInNamedCredential == true
            || String.isNotBlank(dto.linkedInRefreshToken)
            || String.isNotBlank(dto.linkedInClientId)
            || String.isNotBlank(dto.linkedInClientSecret)
            || (String.isNotBlank(dto.linkedInAccessToken) && dto.linkedInAccessToken.length() > 255);

        if (storeSecure) {
            if (dto.useLinkedInNamedCredential == null) {
                dto.useLinkedInNamedCredential = true;
            }
            LinkedInSecretStore.saveTokens(
                dto.linkedInAccessToken,
                dto.linkedInRefreshToken,
                dto.linkedInClientId,
                dto.linkedInClientSecret,
                null
            );
            if (String.isNotBlank(dto.linkedInAccessToken) && dto.linkedInAccessToken.length() <= 255) {
                s.LinkedIn_Access_Token__c = dto.linkedInAccessToken;
            }
        } else if (String.isNotBlank(dto.linkedInAccessToken)) {
            if (dto.linkedInAccessToken.length() > 255) {
                throw new LinkedInAdMetricsException(
                    'LinkedIn Access Token is longer than 255 characters. Enable Use LinkedIn Named Credential to store long tokens.'
                );
            }
            s.LinkedIn_Access_Token__c = dto.linkedInAccessToken;
        }

        if (String.isNotBlank(dto.linkedInAdAccountUrn)) {
            s.LinkedIn_Ad_Account_Urn__c = dto.linkedInAdAccountUrn;
        }
        if (String.isNotBlank(dto.linkedInApiVersion)) {
            s.LinkedIn_API_Version__c = dto.linkedInApiVersion;
        }
        if (String.isNotBlank(dto.hubSpotAccessToken)) {
            s.HubSpot_Access_Token__c = dto.hubSpotAccessToken;
        }
        if (dto.useHubSpotNamedCredential != null) {
            s.Use_HubSpot_Named_Credential__c = dto.useHubSpotNamedCredential;
        }
        if (dto.useLinkedInNamedCredential != null) {
            s.Use_LinkedIn_Named_Credential__c = dto.useLinkedInNamedCredential;
        }
        if (dto.hubSpotBatchSize != null) {
            s.HubSpot_Batch_Size__c = dto.hubSpotBatchSize;
        }
        if (String.isNotBlank(dto.defaultLinkedInCampaignId)) {
            s.Default_LinkedIn_Campaign_Id__c = dto.defaultLinkedInCampaignId;
        }
        if (String.isNotBlank(dto.defaultCampaignName)) {
            s.Default_Campaign_Name__c = dto.defaultCampaignName;
        }
        if (dto.clearDefaultReportStart == true) {
            s.Default_Report_Start__c = null;
        } else if (String.isNotBlank(dto.defaultReportStart)) {
            s.Default_Report_Start__c = Date.valueOf(dto.defaultReportStart);
        }
        if (dto.clearDefaultReportEnd == true) {
            s.Default_Report_End__c = null;
        } else if (String.isNotBlank(dto.defaultReportEnd)) {
            s.Default_Report_End__c = Date.valueOf(dto.defaultReportEnd);
        }
        if (dto.autoSyncEnabled != null) {
            s.Auto_Sync_Enabled__c = dto.autoSyncEnabled;
        }
        if (dto.autoSyncLookbackDays != null) {
            s.Auto_Sync_Lookback_Days__c = dto.autoSyncLookbackDays;
        }
        if (dto.scheduleHour != null) {
            s.Schedule_Hour__c = dto.scheduleHour;
        }
        upsert s;
    }

    public static String getLinkedInAccessToken(LinkedIn_Integration_Settings__c settings) {
        // Prefer secure store + refresh when configured
        if (settings != null && settings.Use_LinkedIn_Named_Credential__c == true) {
            return LinkedInOAuthService.ensureValidAccessToken();
        }
        if (LinkedInSecretStore.hasRefreshCredentials()) {
            return LinkedInOAuthService.ensureValidAccessToken();
        }
        return settings != null ? settings.LinkedIn_Access_Token__c : null;
    }

    private static String resolveLinkedInAccessTokenForUi(LinkedIn_Integration_Settings__c settings) {
        if (settings.Use_LinkedIn_Named_Credential__c == true && LinkedInSecretStore.hasAccessToken()) {
            return null;
        }
        return settings.LinkedIn_Access_Token__c;
    }

    public class LinkedInAdMetricsException extends Exception {}
}