public with sharing class LinkedInAdMetricHubSpotBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    private String campaignFilter;

    public LinkedInAdMetricHubSpotBatch() {}

    public LinkedInAdMetricHubSpotBatch(String campaignName) {
        campaignFilter = campaignName;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (String.isNotBlank(campaignFilter)) {
            return Database.getQueryLocator(
                [
                    SELECT
                        Id,
                        Name,
                        Campaign_Name__c,
                        Company_Name__c,
                        Impressions__c,
                        Clicks__c,
                        Conversions__c,
                        HubSpot_Sync_Status__c,
                        HubSpot_Record_Id__c,
                        HubSpot_Sync_Error__c,
                        Last_HubSpot_Sync__c
                    FROM LinkedIn_Ad_Metric__c
                    WHERE HubSpot_Sync_Status__c IN ('Pending', 'Failed')
                        AND Campaign_Name__c = :campaignFilter
                ]
            );
        }
        return Database.getQueryLocator(
            [
                SELECT
                    Id,
                    Name,
                    Campaign_Name__c,
                    Company_Name__c,
                    Impressions__c,
                    Clicks__c,
                    Conversions__c,
                    HubSpot_Sync_Status__c,
                    HubSpot_Record_Id__c,
                    HubSpot_Sync_Error__c,
                    Last_HubSpot_Sync__c
                FROM LinkedIn_Ad_Metric__c
                WHERE HubSpot_Sync_Status__c IN ('Pending', 'Failed')
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<LinkedIn_Ad_Metric__c> scope) {
        LinkedInHubSpotSyncService.syncRecords(scope);
    }

    public void finish(Database.BatchableContext bc) {}
}