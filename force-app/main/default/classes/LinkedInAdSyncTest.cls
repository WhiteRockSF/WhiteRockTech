@IsTest
private class LinkedInAdSyncTest {
    private class MultiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';

            if (endpoint.contains('oauth/v2/accesstoken')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"new-access-token","expires_in":3600,"refresh_token":"new-refresh"}');
                return res;
            }
            if (endpoint.contains('adanalytics')) {
                res.setStatusCode(200);
                res.setBody(
                    '{"elements":[{"impressions":10,"clicks":2,"externalWebsiteConversions":1,"pivotValues":["urn:li:organization:12345"]}]}'
                );
                return res;
            }
            if (endpoint.contains('organizationslookup')) {
                res.setStatusCode(200);
                res.setBody('{"results":{"12345":{"id":"12345","localizedName":"Acme Corp"}}}');
                return res;
            }
            if (endpoint.contains('adaccounts')) {
                res.setStatusCode(200);
                res.setBody('{"elements":[{"id":1}]}');
                return res;
            }
            if (endpoint.contains('hubapi.com') && endpoint.contains('search')) {
                String body = req.getBody() != null ? req.getBody() : '';
                if (body.contains('Unknown Co')) {
                    res.setStatusCode(200);
                    res.setBody('{"results":[]}');
                    return res;
                }
                res.setStatusCode(200);
                res.setBody('{"results":[{"id":"hs-company-1"}]}');
                return res;
            }
            if (endpoint.contains('hubapi.com') && endpoint.contains('companies')) {
                res.setStatusCode(200);
                res.setBody('{"id":"hs-company-1"}');
                return res;
            }

            res.setStatusCode(404);
            res.setBody('{"message":"not mocked: ' + endpoint + '"}');
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        LinkedIn_Integration_Settings__c s = new LinkedIn_Integration_Settings__c();
        s.SetupOwnerId = UserInfo.getOrganizationId();
        s.LinkedIn_Ad_Account_Urn__c = 'urn:li:sponsoredAccount:506515554';
        s.LinkedIn_API_Version__c = '202607';
        s.Use_HubSpot_Named_Credential__c = false;
        s.Use_LinkedIn_Named_Credential__c = false;
        s.LinkedIn_Access_Token__c = 'linkedin-access-token';
        s.HubSpot_Access_Token__c = 'hubspot-test-token';
        s.HubSpot_Batch_Size__c = 50;
        s.Default_Campaign_Name__c = 'May 26 CTO Peer Perspective';
        s.Default_LinkedIn_Campaign_Id__c = '704412604';
        s.Auto_Sync_Lookback_Days__c = 30;
        insert s;

        insert new LinkedIn_Api_Secret__c(
            Name = 'Default',
            Config_Key__c = 'DEFAULT',
            Access_Token__c = 'old-access-token',
            Refresh_Token__c = 'linkedin-refresh-token',
            Client_Id__c = 'linkedin-client-id',
            Client_Secret__c = 'linkedin-client-secret',
            Access_Token_Expires_At__c = System.now().addDays(30)
        );
    }

    @IsTest
    static void secretStoreAndConfig() {
        LinkedInSecretStore.saveTokens(
            'stored-access-token',
            'stored-refresh-token',
            'stored-client-id',
            'stored-client-secret',
            System.now().addDays(30)
        );

        LinkedInIntegrationSettingsDto dto = new LinkedInIntegrationSettingsDto();
        dto = LinkedInIntegrationConfig.loadDto();
        System.assertEquals('urn:li:sponsoredAccount:506515554', dto.linkedInAdAccountUrn);
        System.assertEquals('202607', dto.linkedInApiVersion);

        dto.defaultCampaignName = 'Updated Campaign';
        dto.hubSpotBatchSize = 25;
        LinkedInIntegrationConfig.saveOrgSettings(dto);
        LinkedInAdMetricsController.saveSettings(JSON.serialize(dto));

        LinkedIn_Integration_Settings__c saved = LinkedInIntegrationConfig.getOrgSettings();
        System.assertEquals('Updated Campaign', saved.Default_Campaign_Name__c);
        System.assertEquals(25, saved.HubSpot_Batch_Size__c);

        System.assertEquals('stored-access-token', LinkedInSecretStore.getAccessToken());
        System.assertEquals(true, LinkedInSecretStore.hasRefreshCredentials());
        System.assertNotEquals(null, LinkedInAdMetricsController.getRecentMetrics('May 26 CTO Peer Perspective', 5));
    }

    @IsTest
    static void controllerValidationErrors() {
        Boolean settingsBlankThrew = false;
        try {
            LinkedInAdMetricsController.saveSettings('');
        } catch (Exception e) {
            settingsBlankThrew = true;
        }
        System.assert(settingsBlankThrew);

        Boolean csvBlankThrew = false;
        try {
            LinkedInAdMetricsController.importCsv('', 'Campaign', '123');
        } catch (Exception e) {
            csvBlankThrew = true;
        }
        System.assert(csvBlankThrew);

        Boolean emptyDtoThrew = false;
        try {
            LinkedInAdMetricsController.saveSettings('{}');
        } catch (Exception e) {
            emptyDtoThrew = true;
        }
        System.assert(emptyDtoThrew);
    }

    @IsTest
    static void fetchMissingAdAccountUrn() {
        LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
        s.LinkedIn_Ad_Account_Urn__c = null;
        upsert s;

        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';
        try {
            LinkedInDemographicsApiService.fetchAndStore(req);
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Ad Account URN'));
        }
    }

    @IsTest
    static void fetchMissingCampaignId() {
        LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
        s.Default_LinkedIn_Campaign_Id__c = null;
        upsert s;

        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        try {
            LinkedInDemographicsApiService.fetchAndStore(req);
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Campaign Id'));
        }
    }

    @IsTest
    static void fetchWithExpandedPivotValue() {
        System.Test.setMock(HttpCalloutMock.class, new PivotValueMock());
        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';
        req.startDate = Date.today();
        req.endDate = Date.today().addDays(-3);

        System.Test.startTest();
        LinkedInDemographicsApiService.FetchResult result = LinkedInDemographicsApiService.fetchAndStore(req);
        System.Test.stopTest();
        System.assertEquals(1, result.rowCount);
        System.assertEquals('Pivot Co', [
            SELECT Company_Name__c FROM LinkedIn_Ad_Metric__c LIMIT 1
        ].Company_Name__c);
    }

    @IsTest
    static void oauthRefreshFailureFallback() {
        LinkedInSecretStore.saveTokens(
            'fallback-token',
            'linkedin-refresh-token',
            'linkedin-client-id',
            'linkedin-client-secret',
            System.now().addHours(1)
        );
        System.Test.setMock(HttpCalloutMock.class, new FailedOAuthMock());
        System.Test.startTest();
        String token = LinkedInOAuthService.ensureValidAccessToken();
        System.Test.stopTest();
        System.assertEquals('fallback-token', token);
    }

    private class PivotValueMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            if (endpoint.contains('adanalytics')) {
                res.setStatusCode(200);
                res.setBody(
                    '{"elements":[{"impressions":4,"clicks":1,"externalWebsiteConversions":0,"pivotValue~":{"localizedName":"Pivot Co"},"pivotValues":["urn:li:organization:555"]}]}'
                );
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class FailedOAuthMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            if (endpoint.contains('oauth/v2/accesstoken')) {
                res.setStatusCode(400);
                res.setBody('{"error":"invalid_grant"}');
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @IsTest
    static void fetchWithoutAccessToken() {
        delete [SELECT Id FROM LinkedIn_Api_Secret__c];
        LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
        s.Use_LinkedIn_Named_Credential__c = false;
        s.LinkedIn_Access_Token__c = null;
        upsert s;

        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';
        try {
            LinkedInDemographicsApiService.fetchAndStore(req);
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Access Token'));
        }
    }

    @IsTest
    static void fetchLinkedInApiError() {
        System.Test.setMock(HttpCalloutMock.class, new ErrorAnalyticsMock());
        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';
        req.startDate = Date.today().addDays(-7);
        req.endDate = Date.today();
        try {
            System.Test.startTest();
            LinkedInDemographicsApiService.fetchAndStore(req);
            System.Test.stopTest();
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('LinkedIn API error'));
        }
    }

    private class ErrorAnalyticsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            if (endpoint.contains('adanalytics')) {
                res.setStatusCode(500);
                res.setBody('{"message":"server error"}');
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @IsTest
    static void oauthTestRefreshWithoutCredentials() {
        delete [SELECT Id FROM LinkedIn_Api_Secret__c];
        System.assert(LinkedInOAuthService.testRefresh().startsWith('ERROR'));
    }

    @IsTest
    static void oauthRefresh() {
        System.Test.setMock(HttpCalloutMock.class, new MultiMock());
        System.Test.startTest();
        LinkedInOAuthService.RefreshResult result = LinkedInOAuthService.refreshAccessToken();
        System.Test.stopTest();
        System.assertEquals(true, result.success);
        System.assertEquals('new-access-token', result.accessToken);
        System.assertEquals('new-access-token', LinkedInSecretStore.getAccessToken());
    }

    @IsTest
    static void linkedInFetchAndConnections() {
        System.Test.setMock(HttpCalloutMock.class, new MultiMock());

        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';
        req.startDate = Date.today().addDays(-7);
        req.endDate = Date.today();

        System.Test.startTest();
        LinkedInDemographicsApiService.FetchResult fetchResult = LinkedInDemographicsApiService.fetchAndStore(req);
        System.Test.stopTest();

        System.assertEquals(1, fetchResult.rowCount);
        System.assertEquals('Acme Corp', [
            SELECT Company_Name__c
            FROM LinkedIn_Ad_Metric__c
            LIMIT 1
        ].Company_Name__c);
        System.assert(LinkedInDemographicsApiService.testConnection().startsWith('SUCCESS'));
    }

    @IsTest
    static void hubSpotSyncAndBatch() {
        System.Test.setMock(HttpCalloutMock.class, new MultiMock());

        List<LinkedInDemographicsCsvParser.DemographicsRow> rows = new List<LinkedInDemographicsCsvParser.DemographicsRow>();
        LinkedInDemographicsCsvParser.DemographicsRow row = new LinkedInDemographicsCsvParser.DemographicsRow();
        row.companyName = 'Acme Corp';
        row.impressions = 10;
        row.clicks = 2;
        row.conversions = 1;
        rows.add(row);
        LinkedInAdMetricRepository.upsertMetrics(
            'May 26 CTO Peer Perspective',
            '704412604',
            'CSV Upload',
            Date.today(),
            Date.today(),
            rows
        );

        LinkedIn_Ad_Metric__c metric = [
            SELECT
                Id,
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
            WHERE Company_Name__c = 'Acme Corp'
            LIMIT 1
        ];

        System.Test.startTest();
        LinkedInHubSpotSyncService.SyncResult syncResult = LinkedInHubSpotSyncService.syncRecords(
            new List<LinkedIn_Ad_Metric__c>{ metric }
        );
        Id jobId = Database.executeBatch(new LinkedInAdMetricHubSpotBatch('May 26 CTO Peer Perspective'), 50);
        System.Test.stopTest();
        System.assert(LinkedInHubSpotSyncService.testConnection().startsWith('SUCCESS'));
        System.assertEquals(1, syncResult.synced, syncResult.failed + ' ' + metric.HubSpot_Sync_Error__c);

        metric = [
            SELECT HubSpot_Sync_Status__c, HubSpot_Record_Id__c
            FROM LinkedIn_Ad_Metric__c
            WHERE Id = :metric.Id
        ];
        System.assertEquals('Synced', metric.HubSpot_Sync_Status__c);
        System.assertEquals('hs-company-1', metric.HubSpot_Record_Id__c);
        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void schedulerAndController() {
        System.Test.setMock(HttpCalloutMock.class, new MultiMock());

        LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
        s.Auto_Sync_Enabled__c = true;
        upsert s;

        System.Test.setMock(HttpCalloutMock.class, new MultiMock());
        LinkedInAdSyncScheduler.scheduleDaily(7, 0);

        System.Test.startTest();
        LinkedInAdSyncScheduler.ScheduleInfo info = LinkedInAdSyncScheduler.getScheduleInfo();
        System.assertEquals(true, info.scheduled);
        System.assertEquals(true, info.autoSyncEnabled);
        LinkedInDemographicsApiService.FetchResult fetchResult = LinkedInAdMetricsController.fetchFromLinkedIn(
            'May 26 CTO Peer Perspective',
            '704412604',
            Date.today().addDays(-7),
            Date.today()
        );
        System.assert(fetchResult.rowCount > 0);
        Id batchJobId = LinkedInAdMetricsController.startHubSpotSyncBatch('May 26 CTO Peer Perspective');
        System.assertNotEquals(null, batchJobId);
        System.Test.stopTest();

        LinkedInAdMetricsController.ImportResult importResult = LinkedInAdMetricsController.importCsv(
            'Demographics Report (In UTC)\nCompany Name Segment,Impressions,Clicks,Conversions\nAcme,5,1,0\n',
            'May 26 CTO Peer Perspective',
            '704412604'
        );
        System.assertEquals(1, importResult.rowCount);

        System.assertNotEquals(null, LinkedInAdMetricsController.getSettings());
        System.assertNotEquals(null, LinkedInAdMetricsController.getRecentMetrics(null, 10));
        System.assertNotEquals(null, LinkedInAdMetricsController.getScheduleStatus());
        System.assertNotEquals(null, LinkedInAdMetricsController.getBatchStatus(batchJobId, 'May 26 CTO Peer Perspective'));
        System.assertEquals(null, LinkedInAdMetricsController.getBatchStatus(null, null).status);

        LinkedInIntegrationSettingsDto dto = new LinkedInIntegrationSettingsDto();
        dto.linkedInApiVersion = '202607';
        dto.linkedInAdAccountUrn = 'urn:li:sponsoredAccount:999';
        dto.autoSyncEnabled = false;
        LinkedInAdMetricsController.saveSettings(JSON.serialize(dto));
        System.assertEquals(
            'urn:li:sponsoredAccount:999',
            LinkedInIntegrationConfig.getOrgSettings().LinkedIn_Ad_Account_Urn__c
        );
        System.assert(LinkedInAdMetricsController.scheduleDailySync(8).startsWith('SUCCESS'));
        System.assert(LinkedInAdMetricsController.stopDailySync().startsWith('SUCCESS'));
    }

    @IsTest
    static void hubSpotCreatesMissingCompany() {
        System.Test.setMock(HttpCalloutMock.class, new MultiMock());
        List<LinkedInDemographicsCsvParser.DemographicsRow> rows = new List<LinkedInDemographicsCsvParser.DemographicsRow>();
        LinkedInDemographicsCsvParser.DemographicsRow row = new LinkedInDemographicsCsvParser.DemographicsRow();
        row.companyName = 'Unknown Co';
        row.impressions = 3;
        rows.add(row);
        LinkedInAdMetricRepository.upsertMetrics(
            'May 26 CTO Peer Perspective',
            '704412604',
            'CSV Upload',
            Date.today(),
            Date.today(),
            rows
        );
        LinkedIn_Ad_Metric__c metric = [
            SELECT Id, Company_Name__c, HubSpot_Sync_Status__c, Impressions__c, Clicks__c, Conversions__c, Campaign_Name__c
            FROM LinkedIn_Ad_Metric__c
            WHERE Company_Name__c = 'Unknown Co'
            LIMIT 1
        ];
        System.Test.startTest();
        LinkedInHubSpotSyncService.SyncResult result = LinkedInHubSpotSyncService.syncRecords(
            new List<LinkedIn_Ad_Metric__c>{ metric }
        );
        System.Test.stopTest();
        System.assertEquals(1, result.synced);
        System.assertEquals(1, result.created);
        metric = [
            SELECT HubSpot_Sync_Status__c, HubSpot_Record_Id__c
            FROM LinkedIn_Ad_Metric__c
            WHERE Id = :metric.Id
        ];
        System.assertEquals('Synced', metric.HubSpot_Sync_Status__c);
        System.assertEquals('hs-company-1', metric.HubSpot_Record_Id__c);
    }

    @IsTest
    static void hubSpotSyncProgressListsCompanies() {
        List<LinkedInDemographicsCsvParser.DemographicsRow> rows = new List<LinkedInDemographicsCsvParser.DemographicsRow>();
        LinkedInDemographicsCsvParser.DemographicsRow row = new LinkedInDemographicsCsvParser.DemographicsRow();
        row.companyName = 'Pending Co';
        row.impressions = 1;
        rows.add(row);
        LinkedInAdMetricRepository.upsertMetrics(
            'May 26 CTO Peer Perspective',
            '704412604',
            'CSV Upload',
            Date.today(),
            Date.today(),
            rows
        );
        LinkedInAdMetricsController.BatchStatus progress = LinkedInAdMetricsController.getBatchStatus(
            null,
            'May 26 CTO Peer Perspective'
        );
        System.assert(progress.pendingCount >= 1);
        System.assert(!progress.pendingCompanies.isEmpty());
    }

    @IsTest
    static void controllerConnectionEndpoints() {
        System.Test.setMock(HttpCalloutMock.class, new MultiMock());
        System.Test.startTest();
        System.assert(LinkedInAdMetricsController.testLinkedInConnection().startsWith('SUCCESS'));
        System.assert(LinkedInAdMetricsController.testHubSpotConnection().startsWith('SUCCESS'));
        System.assert(LinkedInAdMetricsController.refreshLinkedInToken().startsWith('SUCCESS'));
        System.Test.stopTest();
        System.assertNotEquals(null, LinkedInAdMetricsController.getSettings());
    }

    @IsTest
    static void oauthEnsureValidAccessToken() {
        LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
        s.Use_LinkedIn_Named_Credential__c = true;
        upsert s;
        LinkedInSecretStore.saveTokens(
            'old-access-token',
            'linkedin-refresh-token',
            'linkedin-client-id',
            'linkedin-client-secret',
            System.now().addHours(1)
        );

        System.Test.setMock(HttpCalloutMock.class, new MultiMock());
        System.Test.startTest();
        String token = LinkedInOAuthService.ensureValidAccessToken();
        System.Test.stopTest();
        System.assertEquals('new-access-token', token);
    }

    @IsTest
    static void fetchValidationAndEmptyAnalytics() {
        System.Test.setMock(HttpCalloutMock.class, new EmptyAnalyticsMock());

        try {
            LinkedInDemographicsApiService.FetchRequest bad = new LinkedInDemographicsApiService.FetchRequest();
            bad.campaignName = '';
            LinkedInDemographicsApiService.fetchAndStore(bad);
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Campaign Name'));
        }

        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';
        req.startDate = Date.today().addDays(-7);
        req.endDate = Date.today();
        System.Test.startTest();
        LinkedInDemographicsApiService.FetchResult empty = LinkedInDemographicsApiService.fetchAndStore(req);
        System.Test.stopTest();
        System.assertEquals(0, empty.rowCount);
        System.assert(empty.message.contains('0 company rows'));
    }

    private class EmptyAnalyticsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            if (endpoint.contains('adanalytics')) {
                res.setStatusCode(200);
                res.setBody('{"elements":[]}');
                return res;
            }
            if (endpoint.contains('oauth/v2/accesstoken')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"new-access-token","expires_in":3600}');
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @IsTest
    static void schedulerExecute() {
        LinkedIn_Integration_Settings__c s = LinkedInIntegrationConfig.getOrgSettings();
        s.Auto_Sync_Enabled__c = true;
        upsert s;

        System.Test.setMock(HttpCalloutMock.class, new MultiMock());
        System.Test.startTest();
        new LinkedInAdSyncScheduler().execute(null);
        System.Test.stopTest();
    }

    @IsTest
    static void fetchWithNumericCompanyIdAndLookupError() {
        System.Test.setMock(HttpCalloutMock.class, new LookupErrorMock());
        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';
        req.startDate = Date.today().addDays(-7);
        req.endDate = Date.today();

        System.Test.startTest();
        LinkedInDemographicsApiService.FetchResult result = LinkedInDemographicsApiService.fetchAndStore(req);
        System.Test.stopTest();

        System.assertEquals(1, result.rowCount);
        System.assert(result.message.contains('Name lookup'));
    }

    @IsTest
    static void fetchWithLookupUrnFallback() {
        System.Test.setMock(HttpCalloutMock.class, new LookupUrnFallbackMock());
        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';

        System.Test.startTest();
        LinkedInDemographicsApiService.FetchResult result = LinkedInDemographicsApiService.fetchAndStore(req);
        System.Test.stopTest();

        System.assertEquals(1, result.rowCount);
        System.assertEquals('Fallback Corp', [
            SELECT Company_Name__c FROM LinkedIn_Ad_Metric__c LIMIT 1
        ].Company_Name__c);
    }

    @IsTest
    static void fetchWithLocalizedNamePivot() {
        System.Test.setMock(HttpCalloutMock.class, new LocalizedNamePivotMock());
        LinkedInDemographicsApiService.FetchRequest req = new LinkedInDemographicsApiService.FetchRequest();
        req.campaignName = 'May 26 CTO Peer Perspective';
        req.campaignId = '704412604';

        System.Test.startTest();
        LinkedInDemographicsApiService.FetchResult result = LinkedInDemographicsApiService.fetchAndStore(req);
        System.Test.stopTest();

        System.assertEquals(1, result.rowCount);
        System.assertEquals('Localized Co', [
            SELECT Company_Name__c FROM LinkedIn_Ad_Metric__c LIMIT 1
        ].Company_Name__c);
    }

    private class LookupErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            if (endpoint.contains('adanalytics')) {
                res.setStatusCode(200);
                res.setBody(
                    '{"elements":[{"impressions":5,"clicks":1,"externalWebsiteConversions":0,"pivotValues":["urn:li:organization:99999"]}]}'
                );
                return res;
            }
            if (endpoint.contains('organizationslookup')) {
                res.setStatusCode(403);
                res.setBody('{"message":"forbidden"}');
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class LookupUrnFallbackMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            if (endpoint.contains('adanalytics')) {
                res.setStatusCode(200);
                res.setBody(
                    '{"elements":[{"impressions":3,"clicks":0,"externalWebsiteConversions":0,"pivotValues":["urn:li:organization:77777"]}]}'
                );
                return res;
            }
            if (endpoint.contains('organizationslookup') && endpoint.contains('urn:li:organization:77777')) {
                res.setStatusCode(200);
                res.setBody('{"results":{"77777":{"id":"77777","localizedName":"Fallback Corp"}}}');
                return res;
            }
            if (endpoint.contains('organizationslookup')) {
                res.setStatusCode(404);
                res.setBody('{"message":"not found"}');
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class LocalizedNamePivotMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
            if (endpoint.contains('adanalytics')) {
                res.setStatusCode(200);
                res.setBody(
                    '{"elements":[{"impressions":8,"clicks":2,"externalWebsiteConversions":1,'
                    + '"pivotValue~":{"name":{"localized":{"en_US":"Localized Co"}},"id":"88888"},'
                    + '"pivotValues":["urn:li:organization:88888"]}]}'
                );
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }
}