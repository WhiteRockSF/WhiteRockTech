public with sharing class LinkedInAdMetricsController {
    @AuraEnabled(cacheable=true)
    public static LinkedInIntegrationSettingsDto getSettings() {
        return LinkedInIntegrationConfig.loadDto();
    }

    @AuraEnabled
    public static void saveSettings(String settingsJson) {
        if (String.isBlank(settingsJson)) {
            throw new AuraHandledException('Settings are required.');
        }
        LinkedInIntegrationSettingsDto settings;
        try {
            settings = (LinkedInIntegrationSettingsDto) JSON.deserialize(
                settingsJson,
                LinkedInIntegrationSettingsDto.class
            );
        } catch (Exception e) {
            throw new AuraHandledException('Invalid settings payload: ' + e.getMessage());
        }
        if (settings == null) {
            throw new AuraHandledException('Settings are required.');
        }
        Boolean hasAny =
            String.isNotBlank(settings.linkedInAccessToken) ||
            String.isNotBlank(settings.linkedInRefreshToken) ||
            String.isNotBlank(settings.linkedInClientId) ||
            String.isNotBlank(settings.linkedInClientSecret) ||
            String.isNotBlank(settings.linkedInAdAccountUrn) ||
            String.isNotBlank(settings.hubSpotAccessToken) ||
            String.isNotBlank(settings.defaultLinkedInCampaignId) ||
            String.isNotBlank(settings.defaultCampaignName) ||
            String.isNotBlank(settings.defaultReportStart) ||
            String.isNotBlank(settings.defaultReportEnd) ||
            settings.clearDefaultReportStart == true ||
            settings.clearDefaultReportEnd == true ||
            String.isNotBlank(settings.linkedInApiVersion) ||
            settings.hubSpotBatchSize != null ||
            settings.autoSyncLookbackDays != null ||
            settings.scheduleHour != null ||
            settings.useHubSpotNamedCredential != null ||
            settings.useLinkedInNamedCredential != null ||
            settings.autoSyncEnabled != null;
        if (!hasAny) {
            throw new AuraHandledException(
                'No settings received from the form. Enter values and click Save Settings again, or edit Custom Settings in Setup.'
            );
        }
        LinkedInIntegrationConfig.saveOrgSettings(settings);
    }

    @AuraEnabled
    public static ImportResult importCsv(String csvContent, String campaignName, String linkedInCampaignId) {
        try {
            if (String.isBlank(csvContent)) {
                throw new AuraHandledException('CSV content is empty.');
            }
            if (String.isBlank(campaignName)) {
                throw new AuraHandledException('Campaign Name is required.');
            }

            LinkedInDemographicsCsvParser.ParseResult parsed = LinkedInDemographicsCsvParser.parse(csvContent);
            LinkedInAdMetricRepository.UpsertResult repoResult = LinkedInAdMetricRepository.upsertMetrics(
                campaignName.trim(),
                linkedInCampaignId,
                'CSV Upload',
                parsed.reportStart,
                parsed.reportEnd,
                parsed.rows
            );

            ImportResult result = new ImportResult();
            result.rowCount = parsed.rows.size();
            result.inserted = repoResult.inserted;
            result.updated = repoResult.updated;
            result.skipped = parsed.skippedRows + repoResult.skipped;
            result.message = 'Imported ' + parsed.rows.size() + ' company rows for campaign "' + campaignName + '".';
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static LinkedInDemographicsApiService.FetchResult fetchFromLinkedIn(
        String campaignName,
        String linkedInCampaignId,
        Date reportStart,
        Date reportEnd
    ) {
        try {
            LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
            req.campaignName = campaignName;
            req.campaignId = linkedInCampaignId;
            req.startDate = reportStart;
            req.endDate = reportEnd;
            return LinkedInDemographicsApiService.fetchAndStore(req);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String startHubSpotSyncBatch(String campaignName) {
        try {
            LinkedIn_Integration_Settings__c settings = LinkedInIntegrationConfig.getOrgSettings();
            Integer batchSize = settings.HubSpot_Batch_Size__c != null
                ? Integer.valueOf(settings.HubSpot_Batch_Size__c.intValue())
                : 50;
            LinkedInAdMetricHubSpotBatch batch = String.isNotBlank(campaignName)
                ? new LinkedInAdMetricHubSpotBatch(campaignName.trim())
                : new LinkedInAdMetricHubSpotBatch();
            return Database.executeBatch(batch, batchSize);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<MetricRow> getRecentMetrics(String campaignName, Integer rowLimit) {
        Integer lim = rowLimit != null && rowLimit > 0 ? rowLimit : 50;
        List<LinkedIn_Ad_Metric__c> rows;
        if (String.isNotBlank(campaignName)) {
            rows = [
                SELECT
                    Id,
                    Name,
                    Campaign_Name__c,
                    Company_Name__c,
                    Impressions__c,
                    Clicks__c,
                    Conversions__c,
                    HubSpot_Sync_Status__c,
                    HubSpot_Sync_Error__c,
                    Last_HubSpot_Sync__c,
                    Source__c
                FROM LinkedIn_Ad_Metric__c
                WHERE Campaign_Name__c = :campaignName
                ORDER BY LastModifiedDate DESC
                LIMIT :lim
            ];
        } else {
            rows = [
                SELECT
                    Id,
                    Name,
                    Campaign_Name__c,
                    Company_Name__c,
                    Impressions__c,
                    Clicks__c,
                    Conversions__c,
                    HubSpot_Sync_Status__c,
                    HubSpot_Sync_Error__c,
                    Last_HubSpot_Sync__c,
                    Source__c
                FROM LinkedIn_Ad_Metric__c
                ORDER BY LastModifiedDate DESC
                LIMIT :lim
            ];
        }

        List<MetricRow> out = new List<MetricRow>();
        for (LinkedIn_Ad_Metric__c r : rows) {
            MetricRow m = new MetricRow();
            m.id = r.Id;
            m.name = r.Name;
            m.campaignName = r.Campaign_Name__c;
            m.companyName = r.Company_Name__c;
            m.impressions = r.Impressions__c;
            m.clicks = r.Clicks__c;
            m.conversions = r.Conversions__c;
            m.syncStatus = r.HubSpot_Sync_Status__c;
            m.syncError = r.HubSpot_Sync_Error__c;
            m.lastSync = r.Last_HubSpot_Sync__c;
            m.source = r.Source__c;
            out.add(m);
        }
        return out;
    }

    @AuraEnabled
    public static String testLinkedInConnection() {
        return LinkedInDemographicsApiService.testConnection();
    }

    @AuraEnabled
    public static String refreshLinkedInToken() {
        return LinkedInOAuthService.testRefresh();
    }

    @AuraEnabled
    public static String testHubSpotConnection() {
        return LinkedInHubSpotSyncService.testConnection();
    }

    @AuraEnabled
    public static LinkedInAdSyncScheduler.ScheduleInfo getScheduleStatus() {
        return LinkedInAdSyncScheduler.getScheduleInfo();
    }

    @AuraEnabled
    public static String scheduleDailySync(Integer hour) {
        try {
            Integer h = hour != null ? hour : 6;
            String jobId = LinkedInAdSyncScheduler.scheduleDaily(h, 0);
            return 'SUCCESS: Daily job scheduled at ' + h + ':00 (org timezone). Job Id: ' + jobId;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String stopDailySync() {
        try {
            Integer n = LinkedInAdSyncScheduler.abortExistingJobs();
            LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
            s.Auto_Sync_Enabled__c = false;
            upsert s;
            return n > 0
                ? 'SUCCESS: Stopped ' + n + ' scheduled job(s). Auto Sync disabled.'
                : 'SUCCESS: No scheduled job found. Auto Sync disabled.';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static BatchStatus getBatchStatus(Id jobId, String campaignName) {
        BatchStatus s = new BatchStatus();
        if (jobId != null) {
            AsyncApexJob job = [
                SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, ExtendedStatus
                FROM AsyncApexJob
                WHERE Id = :jobId
                LIMIT 1
            ];
            s.status = job.Status;
            s.errors = job.NumberOfErrors;
            s.processed = job.JobItemsProcessed;
            s.total = job.TotalJobItems;
            s.extendedStatus = job.ExtendedStatus;
        }
        enrichBatchProgress(s, campaignName);
        return s;
    }

    private static void enrichBatchProgress(BatchStatus s, String campaignName) {
        Datetime since = System.now().addMinutes(-30);
        String camp = String.isNotBlank(campaignName) ? campaignName.trim() : null;

        List<AggregateResult> counts;
        if (camp != null) {
            counts = [
                SELECT HubSpot_Sync_Status__c status, COUNT(Id) cnt
                FROM LinkedIn_Ad_Metric__c
                WHERE Campaign_Name__c = :camp
                GROUP BY HubSpot_Sync_Status__c
            ];
        } else {
            counts = [
                SELECT HubSpot_Sync_Status__c status, COUNT(Id) cnt
                FROM LinkedIn_Ad_Metric__c
                GROUP BY HubSpot_Sync_Status__c
            ];
        }
        s.pendingCount = 0;
        s.syncedCount = 0;
        s.failedCount = 0;
        s.skippedCount = 0;
        for (AggregateResult ar : counts) {
            String st = (String) ar.get('status');
            Integer cnt = (Integer) ar.get('cnt');
            if (st == 'Pending') {
                s.pendingCount = cnt;
            } else if (st == 'Synced') {
                s.syncedCount = cnt;
            } else if (st == 'Failed') {
                s.failedCount = cnt;
            } else if (st == 'Skipped') {
                s.skippedCount = cnt;
            }
        }

        List<LinkedIn_Ad_Metric__c> recent;
        if (camp != null) {
            recent = [
                SELECT Company_Name__c, HubSpot_Sync_Status__c, HubSpot_Sync_Error__c, Last_HubSpot_Sync__c
                FROM LinkedIn_Ad_Metric__c
                WHERE Campaign_Name__c = :camp
                    AND Last_HubSpot_Sync__c >= :since
                    AND HubSpot_Sync_Status__c IN ('Synced', 'Failed', 'Skipped')
                ORDER BY Last_HubSpot_Sync__c DESC
                LIMIT 20
            ];
        } else {
            recent = [
                SELECT Company_Name__c, HubSpot_Sync_Status__c, HubSpot_Sync_Error__c, Last_HubSpot_Sync__c
                FROM LinkedIn_Ad_Metric__c
                WHERE Last_HubSpot_Sync__c >= :since
                    AND HubSpot_Sync_Status__c IN ('Synced', 'Failed', 'Skipped')
                ORDER BY Last_HubSpot_Sync__c DESC
                LIMIT 20
            ];
        }

        s.recentCompanies = new List<String>();
        for (LinkedIn_Ad_Metric__c row : recent) {
            String label = row.Company_Name__c;
            if (String.isBlank(label)) {
                continue;
            }
            if (row.HubSpot_Sync_Status__c == 'Failed') {
                label += ' (Failed)';
            } else if (row.HubSpot_Sync_Status__c == 'Skipped') {
                label += ' (Skipped)';
            }
            s.recentCompanies.add(label);
        }

        List<LinkedIn_Ad_Metric__c> pending;
        if (camp != null) {
            pending = [
                SELECT Company_Name__c
                FROM LinkedIn_Ad_Metric__c
                WHERE Campaign_Name__c = :camp
                    AND HubSpot_Sync_Status__c = 'Pending'
                ORDER BY Company_Name__c ASC
                LIMIT 15
            ];
        } else {
            pending = [
                SELECT Company_Name__c
                FROM LinkedIn_Ad_Metric__c
                WHERE HubSpot_Sync_Status__c = 'Pending'
                ORDER BY Company_Name__c ASC
                LIMIT 15
            ];
        }
        s.pendingCompanies = new List<String>();
        for (LinkedIn_Ad_Metric__c row : pending) {
            if (String.isNotBlank(row.Company_Name__c)) {
                s.pendingCompanies.add(row.Company_Name__c);
            }
        }
    }

    public class ImportResult {
        @AuraEnabled public Integer rowCount;
        @AuraEnabled public Integer inserted;
        @AuraEnabled public Integer updated;
        @AuraEnabled public Integer skipped;
        @AuraEnabled public String message;
    }

    public class MetricRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String campaignName;
        @AuraEnabled public String companyName;
        @AuraEnabled public Decimal impressions;
        @AuraEnabled public Decimal clicks;
        @AuraEnabled public Decimal conversions;
        @AuraEnabled public String syncStatus;
        @AuraEnabled public String syncError;
        @AuraEnabled public Datetime lastSync;
        @AuraEnabled public String source;
    }

    public class BatchStatus {
        @AuraEnabled public String status;
        @AuraEnabled public Integer errors;
        @AuraEnabled public Integer processed;
        @AuraEnabled public Integer total;
        @AuraEnabled public String extendedStatus;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public Integer syncedCount;
        @AuraEnabled public Integer failedCount;
        @AuraEnabled public Integer skippedCount;
        @AuraEnabled public List<String> pendingCompanies;
        @AuraEnabled public List<String> recentCompanies;
    }
}