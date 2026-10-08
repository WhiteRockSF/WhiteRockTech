/**
 * Scheduled LinkedIn fetch (active CMDT campaigns + default campaign) + HubSpot batch.
 * Manage from LinkedIn Ad Sync LWC or: Setup → Apex Classes → Schedule Apex.
 */
public with sharing class LinkedInAdSyncScheduler implements Schedulable, Database.AllowsCallouts {
    public static final String JOB_NAME = 'LinkedIn Ad Sync Daily';

    public void execute(SchedulableContext ctx) {
        LinkedIn_Integration_Settings__c settings = LinkedInIntegrationConfig.getOrgSettings();
        if (settings.Auto_Sync_Enabled__c != true) {
            return;
        }
        if (String.isBlank(LinkedInIntegrationConfig.getLinkedInAccessToken(settings))) {
            System.debug(LoggingLevel.ERROR, '[LinkedInAdSyncScheduler] LinkedIn Access Token not configured.');
            return;
        }

        Integer lookback = settings.Auto_Sync_Lookback_Days__c != null
            ? Integer.valueOf(settings.Auto_Sync_Lookback_Days__c.intValue())
            : 30;
        Date endDate = Date.today();
        Date startDate = endDate.addDays(-lookback);

        List<CampaignTarget> targets = resolveCampaigns(settings);
        if (targets.isEmpty()) {
            System.debug(
                LoggingLevel.WARN,
                '[LinkedInAdSyncScheduler] No campaigns: set Default Campaign Name/Id in API Settings or add LinkedIn Scheduled Campaign metadata.'
            );
            return;
        }

        for (CampaignTarget c : targets) {
            try {
                LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
                req.campaignName = c.campaignName;
                req.campaignId = c.campaignId;
                req.startDate = startDate;
                req.endDate = endDate;
                LinkedInDemographicsApiService.fetchAndStore(req);
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    '[LinkedInAdSyncScheduler] Campaign failed: ' + c.campaignName + ' — ' + e.getMessage()
                );
            }
        }

        Integer batchSize = settings.HubSpot_Batch_Size__c != null
            ? Integer.valueOf(settings.HubSpot_Batch_Size__c.intValue())
            : 50;
        Database.executeBatch(new LinkedInAdMetricHubSpotBatch(), batchSize);
    }

    private class CampaignTarget {
        String campaignName;
        String campaignId;
        CampaignTarget(String n, String i) {
            campaignName = n;
            campaignId = i;
        }
    }

    private static List<CampaignTarget> resolveCampaigns(LinkedIn_Integration_Settings__c settings) {
        List<CampaignTarget> out = new List<CampaignTarget>();
        Set<String> seen = new Set<String>();

        for (LinkedIn_Scheduled_Campaign__mdt c : [
            SELECT Campaign_Name__c, LinkedIn_Campaign_Id__c
            FROM LinkedIn_Scheduled_Campaign__mdt
            WHERE Active__c = TRUE
        ]) {
            if (String.isBlank(c.Campaign_Name__c)) {
                continue;
            }
            String key = c.Campaign_Name__c.trim().toLowerCase();
            if (seen.contains(key)) {
                continue;
            }
            seen.add(key);
            out.add(new CampaignTarget(c.Campaign_Name__c.trim(), c.LinkedIn_Campaign_Id__c));
        }

        if (String.isNotBlank(settings.Default_Campaign_Name__c)) {
            String key = settings.Default_Campaign_Name__c.trim().toLowerCase();
            if (!seen.contains(key)) {
                out.add(
                    new CampaignTarget(
                        settings.Default_Campaign_Name__c.trim(),
                        settings.Default_LinkedIn_Campaign_Id__c
                    )
                );
            }
        }
        return out;
    }

    /** Daily cron in org timezone. Hour 0-23, minute 0-59. */
    public static String scheduleDaily(Integer hour, Integer minute) {
        Integer h = hour != null ? hour : 6;
        Integer m = minute != null ? minute : 0;
        if (h < 0 || h > 23) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException('Schedule hour must be 0–23.');
        }
        if (m < 0 || m > 59) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException('Schedule minute must be 0–59.');
        }
        abortExistingJobs();
        String cron = '0 ' + m + ' ' + h + ' * * ?';
        String jobId = System.schedule(JOB_NAME, cron, new LinkedInAdSyncScheduler());
        LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
        s.Schedule_Hour__c = h;
        s.Auto_Sync_Enabled__c = true;
        upsert s;
        return jobId;
    }

    public static Integer abortExistingJobs() {
        Integer aborted = 0;
        for (CronTrigger ct : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
        ]) {
            System.abortJob(ct.Id);
            aborted++;
        }
        return aborted;
    }

    public static ScheduleInfo getScheduleInfo() {
        ScheduleInfo info = new ScheduleInfo();
        info.jobName = JOB_NAME;
        info.scheduled = false;
        LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
        info.scheduleHour = s.Schedule_Hour__c != null ? Integer.valueOf(s.Schedule_Hour__c.intValue()) : 6;
        info.autoSyncEnabled = s.Auto_Sync_Enabled__c == true;

        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, NextFireTime, State, TimesTriggered, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!jobs.isEmpty()) {
            CronTrigger ct = jobs[0];
            info.scheduled = true;
            info.cronTriggerId = ct.Id;
            info.cronExpression = ct.CronExpression;
            info.nextFireTime = ct.NextFireTime;
            info.state = ct.State;
            info.timesTriggered = ct.TimesTriggered;
            // Prefer hour parsed from cron "0 m h * * ?"
            List<String> parts = ct.CronExpression != null ? ct.CronExpression.split(' ') : new List<String>();
            if (parts.size() >= 3) {
                try {
                    info.scheduleHour = Integer.valueOf(parts[2]);
                } catch (Exception e) {
                    // keep settings hour
                }
            }
        }

        List<String> names = new List<String>();
        for (CampaignTarget t : resolveCampaigns(s)) {
            names.add(t.campaignName + (String.isNotBlank(t.campaignId) ? ' (' + t.campaignId + ')' : ''));
        }
        info.campaignSummary = names.isEmpty() ? 'None — set Default Campaign Name/Id' : String.join(names, '; ');
        return info;
    }

    public class ScheduleInfo {
        @AuraEnabled public String jobName;
        @AuraEnabled public Boolean scheduled;
        @AuraEnabled public Boolean autoSyncEnabled;
        @AuraEnabled public Integer scheduleHour;
        @AuraEnabled public String cronTriggerId;
        @AuraEnabled public String cronExpression;
        @AuraEnabled public Datetime nextFireTime;
        @AuraEnabled public String state;
        @AuraEnabled public Integer timesTriggered;
        @AuraEnabled public String campaignSummary;
    }
}