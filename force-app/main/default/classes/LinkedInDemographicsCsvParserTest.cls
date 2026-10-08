@IsTest
private class LinkedInDemographicsCsvParserTest {
    @TestSetup
    static void makeData() {
        LinkedIn_Integration_Settings__c s = new LinkedIn_Integration_Settings__c();
        s.SetupOwnerId = UserInfo.getOrganizationId();
        s.LinkedIn_API_Version__c = '202405';
        s.Use_HubSpot_Named_Credential__c = true;
        s.HubSpot_Batch_Size__c = 50;
        insert s;
    }

    @IsTest
    static void parsesCompanyNameSegment() {
        String csv =
            'Demographics Report (In UTC)\n' +
            'Report Start,"April 28, 2026, 12:00 AM"\n' +
            'Report End,"May 27, 2026, 11:59 PM"\n' +
            '\n' +
            'Company Name Segment,Impressions,Clicks,Conversions\n' +
            'CompHealth,8,0,0\n' +
            'Numotion,8,1,0\n' +
            'Company Industry Segment,100,0,0\n';

        LinkedInDemographicsCsvParser.ParseResult result = LinkedInDemographicsCsvParser.parse(csv);
        System.assertEquals(2, result.rows.size(), 'Should parse two company rows before industry segment');
        System.assertEquals('CompHealth', result.rows[0].companyName);
        System.assertEquals(8, result.rows[0].impressions);
        System.assertEquals('Numotion', result.rows[1].companyName);
        System.assertEquals(1, result.rows[1].clicks);
    }

    @IsTest
    static void parsesTabDelimitedCompanySegment() {
        String csv =
            'Demographics Report (in UTC)\n' +
            '"Report Start: June 21, 2026, 12:00 AM"\n' +
            '\n' +
            'Company Name Segment\tImpressions\tPercent of Total Impressions\tClicks\tConversions\n' +
            'CompHealth\t11\t5%\t0\t0\n' +
            'Numotion\t8\t4%\t1\t0\n' +
            '\n' +
            'Company Industry Segment\tImpressions\tClicks\tConversions\n' +
            'Software\t100\t0\t0\n';

        LinkedInDemographicsCsvParser.ParseResult result = LinkedInDemographicsCsvParser.parse(csv);
        System.assertEquals(2, result.rows.size(), 'Should parse tab-delimited company rows');
        System.assertEquals('CompHealth', result.rows[0].companyName);
        System.assertEquals(11, result.rows[0].impressions);
        System.assertEquals(1, result.rows[1].clicks);
    }

    @IsTest
    static void deduplicatesByCampaignAndCompany() {
        List<LinkedInDemographicsCsvParser.DemographicsRow> rows = new List<LinkedInDemographicsCsvParser.DemographicsRow>();
        LinkedInDemographicsCsvParser.DemographicsRow r = new LinkedInDemographicsCsvParser.DemographicsRow();
        r.companyName = 'Acme Corp';
        r.impressions = 10;
        r.clicks = 2;
        r.conversions = 1;
        rows.add(r);

        LinkedInAdMetricRepository.upsertMetrics('May Campaign', '123', 'CSV Upload', Date.today(), Date.today(), rows);
        r.impressions = 20;
        LinkedInAdMetricRepository.upsertMetrics('May Campaign', '123', 'CSV Upload', Date.today(), Date.today(), rows);

        List<LinkedIn_Ad_Metric__c> stored = [
            SELECT Id, Impressions__c, Sync_Key__c
            FROM LinkedIn_Ad_Metric__c
            WHERE Campaign_Name__c = 'May Campaign'
        ];
        System.assertEquals(1, stored.size(), 'Same campaign+company must not duplicate');
        System.assertEquals(20, stored[0].Impressions__c);
    }
}