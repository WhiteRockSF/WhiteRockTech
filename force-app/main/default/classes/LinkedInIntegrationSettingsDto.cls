/** Top-level DTO for LWC ↔ Apex (inner classes do not deserialize from JavaScript). */
public with sharing class LinkedInIntegrationSettingsDto {
    @AuraEnabled public String linkedInAccessToken;
    @AuraEnabled public String linkedInRefreshToken;
    @AuraEnabled public String linkedInClientId;
    @AuraEnabled public String linkedInClientSecret;
    @AuraEnabled public Boolean linkedInRefreshConfigured;
    @AuraEnabled public String linkedInAdAccountUrn;
    @AuraEnabled public String linkedInApiVersion;
    @AuraEnabled public String hubSpotAccessToken;
    @AuraEnabled public Boolean useHubSpotNamedCredential;
    @AuraEnabled public Boolean useLinkedInNamedCredential;
    @AuraEnabled public Decimal hubSpotBatchSize;
    @AuraEnabled public String defaultLinkedInCampaignId;
    @AuraEnabled public String defaultCampaignName;
    @AuraEnabled public String defaultReportStart;
    @AuraEnabled public String defaultReportEnd;
    @AuraEnabled public Boolean clearDefaultReportStart;
    @AuraEnabled public Boolean clearDefaultReportEnd;
    @AuraEnabled public String hubSpotTargetType;
    @AuraEnabled public String hubSpotCustomObjectTypeId;
    @AuraEnabled public String propImpressions;
    @AuraEnabled public String propClicks;
    @AuraEnabled public String propConversions;
    @AuraEnabled public String propCampaign;
    @AuraEnabled public Boolean autoSyncEnabled;
    @AuraEnabled public Decimal autoSyncLookbackDays;
    @AuraEnabled public Decimal scheduleHour;
    @AuraEnabled public Boolean scheduleJobActive;
    @AuraEnabled public String scheduleNextFire;
    @AuraEnabled public String scheduleState;
    @AuraEnabled public String scheduleCampaignSummary;
}