public with sharing class LinkedInAdMetricRepository {
    public class UpsertResult {
        public Integer inserted = 0;
        public Integer updated = 0;
        public Integer skipped = 0;
    }

    public static UpsertResult upsertMetrics(
        String campaignName,
        String linkedInCampaignId,
        String source,
        Date reportStart,
        Date reportEnd,
        List<LinkedInDemographicsCsvParser.DemographicsRow> rows
    ) {
        UpsertResult result = new UpsertResult();
        if (String.isBlank(campaignName) || rows == null || rows.isEmpty()) {
            return result;
        }

        Set<String> syncKeys = new Set<String>();
        List<LinkedIn_Ad_Metric__c> records = new List<LinkedIn_Ad_Metric__c>();
        for (LinkedInDemographicsCsvParser.DemographicsRow row : rows) {
            String syncKey = LinkedInAdMetricKeys.buildSyncKey(campaignName, row.companyName);
            if (String.isBlank(syncKey)) {
                result.skipped++;
                continue;
            }
            syncKeys.add(syncKey);
            LinkedIn_Ad_Metric__c rec = new LinkedIn_Ad_Metric__c();
            rec.Name = LinkedInAdMetricKeys.buildRecordName(campaignName, row.companyName);
            rec.Sync_Key__c = syncKey;
            rec.Campaign_Name__c = campaignName.trim();
            rec.Company_Name__c = row.companyName;
            rec.Impressions__c = row.impressions;
            rec.Clicks__c = row.clicks;
            rec.Conversions__c = row.conversions;
            rec.Report_Start_Date__c = reportStart;
            rec.Report_End_Date__c = reportEnd;
            rec.Source__c = source;
            rec.LinkedIn_Campaign_Id__c = linkedInCampaignId;
            rec.HubSpot_Sync_Status__c = 'Pending';
            records.add(rec);
        }

        Map<String, LinkedIn_Ad_Metric__c> existingByKey = new Map<String, LinkedIn_Ad_Metric__c>();
        for (LinkedIn_Ad_Metric__c ex : [
            SELECT Id, Sync_Key__c
            FROM LinkedIn_Ad_Metric__c
            WHERE Sync_Key__c IN :syncKeys
        ]) {
            existingByKey.put(ex.Sync_Key__c, ex);
        }

        for (LinkedIn_Ad_Metric__c rec : records) {
            if (existingByKey.containsKey(rec.Sync_Key__c)) {
                rec.Id = existingByKey.get(rec.Sync_Key__c).Id;
                result.updated++;
            } else {
                result.inserted++;
            }
        }

        if (!records.isEmpty()) {
            upsert records Sync_Key__c;
        }
        return result;
    }
}