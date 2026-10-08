public with sharing class LinkedInHubSpotSyncService {
    public class SyncResult {
        public Integer processed = 0;
        public Integer synced = 0;
        public Integer created = 0;
        public Integer failed = 0;
        public Integer skipped = 0;
        public List<String> companyNames = new List<String>();
    }

    public static SyncResult syncRecords(List<LinkedIn_Ad_Metric__c> metrics) {
        SyncResult result = new SyncResult();
        if (metrics == null || metrics.isEmpty()) {
            return result;
        }

        LinkedIn_HubSpot_Config__mdt cfg = LinkedInIntegrationConfig.getHubSpotConfig();
        LinkedIn_Integration_Settings__c settings = LinkedInIntegrationConfig.getOrgSettings();
        Boolean useNamedCredential = settings.Use_HubSpot_Named_Credential__c != false;

        List<LinkedIn_Ad_Metric__c> toUpdate = new List<LinkedIn_Ad_Metric__c>();

        for (LinkedIn_Ad_Metric__c metric : metrics) {
            result.processed++;
            if (String.isNotBlank(metric.Company_Name__c)) {
                result.companyNames.add(metric.Company_Name__c);
            }
            try {
                UpsertOutcome outcome = upsertHubSpotCompany(metric, cfg, settings, useNamedCredential);
                if (String.isBlank(outcome.hubspotId)) {
                    metric.HubSpot_Sync_Status__c = 'Skipped';
                    metric.HubSpot_Record_Id__c = null;
                    result.skipped++;
                } else {
                    metric.HubSpot_Sync_Status__c = 'Synced';
                    metric.HubSpot_Record_Id__c = outcome.hubspotId;
                    result.synced++;
                    if (outcome.created) {
                        result.created++;
                    }
                }
                metric.HubSpot_Sync_Error__c = null;
                metric.Last_HubSpot_Sync__c = System.now();
            } catch (Exception e) {
                metric.HubSpot_Sync_Status__c = 'Failed';
                metric.HubSpot_Sync_Error__c = e.getMessage();
                metric.Last_HubSpot_Sync__c = System.now();
                result.failed++;
            }
            toUpdate.add(metric);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        return result;
    }

    private class UpsertOutcome {
        String hubspotId;
        Boolean created = false;
    }

    private static UpsertOutcome upsertHubSpotCompany(
        LinkedIn_Ad_Metric__c metric,
        LinkedIn_HubSpot_Config__mdt cfg,
        LinkedIn_Integration_Settings__c settings,
        Boolean useNamedCredential
    ) {
        UpsertOutcome outcome = new UpsertOutcome();
        if (String.isBlank(metric.Company_Name__c)) {
            return outcome;
        }

        Map<String, Object> properties = buildProperties(metric, cfg);
        String existingId = searchCompanyId(metric.Company_Name__c, settings, useNamedCredential);
        if (String.isBlank(existingId)) {
            outcome.hubspotId = createCompany(properties, settings, useNamedCredential);
            outcome.created = true;
            return outcome;
        }
        patchCompany(existingId, properties, settings, useNamedCredential);
        outcome.hubspotId = existingId;
        return outcome;
    }

    private static Map<String, Object> buildProperties(
        LinkedIn_Ad_Metric__c metric,
        LinkedIn_HubSpot_Config__mdt cfg
    ) {
        Map<String, Object> props = new Map<String, Object>();
        props.put('name', metric.Company_Name__c);
        if (String.isNotBlank(cfg.HubSpot_Property_Impressions__c)) {
            props.put(cfg.HubSpot_Property_Impressions__c, metric.Impressions__c != null ? metric.Impressions__c : 0);
        }
        if (String.isNotBlank(cfg.HubSpot_Property_Clicks__c)) {
            props.put(cfg.HubSpot_Property_Clicks__c, metric.Clicks__c != null ? metric.Clicks__c : 0);
        }
        if (String.isNotBlank(cfg.HubSpot_Property_Conversions__c)) {
            props.put(cfg.HubSpot_Property_Conversions__c, metric.Conversions__c != null ? metric.Conversions__c : 0);
        }
        if (String.isNotBlank(cfg.HubSpot_Property_Campaign__c) && String.isNotBlank(metric.Campaign_Name__c)) {
            props.put(cfg.HubSpot_Property_Campaign__c, metric.Campaign_Name__c);
        }
        return props;
    }

    private static String searchCompanyId(
        String companyName,
        LinkedIn_Integration_Settings__c settings,
        Boolean useNamedCredential
    ) {
        Map<String, Object> body = new Map<String, Object>{
            'filterGroups' => new List<Object>{
                new Map<String, Object>{
                    'filters' => new List<Object>{
                        new Map<String, Object>{
                            'propertyName' => 'name',
                            'operator' => 'EQ',
                            'value' => companyName
                        }
                    }
                }
            },
            'properties' => new List<String>{ 'name' },
            'limit' => 2
        };

        HttpResponse res = hubSpotRequest(
            'POST',
            '/crm/v3/objects/companies/search',
            JSON.serialize(body),
            settings,
            useNamedCredential
        );
        if (res.getStatusCode() != 200) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException(
                'HubSpot search failed: ' + res.getStatusCode() + ' ' + res.getBody()
            );
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> results = (List<Object>) parsed.get('results');
        if (results == null || results.isEmpty()) {
            return null;
        }
        if (results.size() > 1) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException(
                'Multiple HubSpot companies match: ' + companyName
            );
        }
        Map<String, Object> first = (Map<String, Object>) results[0];
        return String.valueOf(first.get('id'));
    }

    private static String createCompany(
        Map<String, Object> properties,
        LinkedIn_Integration_Settings__c settings,
        Boolean useNamedCredential
    ) {
        Map<String, Object> body = new Map<String, Object>{ 'properties' => properties };
        HttpResponse res = hubSpotRequest(
            'POST',
            '/crm/v3/objects/companies',
            JSON.serialize(body),
            settings,
            useNamedCredential
        );
        if (res.getStatusCode() != 201 && res.getStatusCode() != 200) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException(
                'HubSpot create failed: ' + res.getStatusCode() + ' ' + res.getBody()
            );
        }
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return String.valueOf(parsed.get('id'));
    }

    private static void patchCompany(
        String companyId,
        Map<String, Object> properties,
        LinkedIn_Integration_Settings__c settings,
        Boolean useNamedCredential
    ) {
        Map<String, Object> body = new Map<String, Object>{ 'properties' => properties };
        HttpResponse res = hubSpotRequest(
            'PATCH',
            '/crm/v3/objects/companies/' + companyId,
            JSON.serialize(body),
            settings,
            useNamedCredential
        );
        if (res.getStatusCode() != 200) {
            throw new LinkedInIntegrationConfig.LinkedInAdMetricsException(
                'HubSpot update failed: ' + res.getStatusCode() + ' ' + res.getBody()
            );
        }
    }

    private static HttpResponse hubSpotRequest(
        String method,
        String path,
        String body,
        LinkedIn_Integration_Settings__c settings,
        Boolean useNamedCredential
    ) {
        HttpRequest req = new HttpRequest();
        if (useNamedCredential) {
            req.setEndpoint('callout:HubSpot' + path);
        } else {
            req.setEndpoint('https://api.hubapi.com' + path);
            req.setHeader('Authorization', 'Bearer ' + settings.HubSpot_Access_Token__c);
        }
        req.setMethod(method);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);
        if (String.isNotBlank(body) && method != 'GET') {
            req.setBody(body);
        }
        return new Http().send(req);
    }

    public static String testConnection() {
        LinkedIn_Integration_Settings__c settings = LinkedInIntegrationConfig.getOrgSettings();
        Boolean useNamedCredential = settings.Use_HubSpot_Named_Credential__c != false;
        if (!useNamedCredential && String.isBlank(settings.HubSpot_Access_Token__c)) {
            return 'ERROR: HubSpot token not configured';
        }
        HttpResponse res = hubSpotRequest('GET', '/crm/v3/objects/companies?limit=1', null, settings, useNamedCredential);
        return res.getStatusCode() == 200
            ? 'SUCCESS: HubSpot API reachable.'
            : 'ERROR ' + res.getStatusCode() + ': ' + res.getBody();
    }
}