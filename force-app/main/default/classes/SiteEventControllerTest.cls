@IsTest
private class SiteEventControllerTest {
    
    @IsTest
    static void testDoGet() {
        // Test the GET endpoint
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/event';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        System.Test.startTest();
        String result = SiteEventController.doGet();
        System.Test.stopTest();
        
        System.assertEquals('doGet', result, 'GET endpoint should return "doGet"');
    }
    
    @IsTest
    static void testDoPostSuccess() {
        // Test the POST endpoint with valid data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        SiteEventController.EventWrapper testEvent = new SiteEventController.EventWrapper();
        testEvent.title = 'Test Resource';
        testEvent.clientId = '12345';
        testEvent.type = 'Page View';
        testEvent.url = 'https://System.Test.example.com';
        testEvent.ip = '192.168.1.1';
        testEvent.timezone = 'America/New_York';
        testEvent.country = 'United States';
        testEvent.region = 'New York';
        testEvent.city = 'New York City';
        testEvent.latitude = 40.7128;
        testEvent.longitude = -74.0060;
        
        String jsonEvent = JSON.serialize(testEvent);
        
        req.requestURI = '/services/apexrest/event';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonEvent);
        
        RestContext.request = req;
        RestContext.response = res;
        
        System.Test.startTest();
        SiteEventController.doPost();
        System.Test.stopTest();
        
        // Verify the record was created
        List<Site_Event__c> createdEvents = [SELECT Id, Resource__c, Client_Id__c, Type__c 
                                           FROM Site_Event__c];
        System.assertEquals(1, createdEvents.size(), 'Exactly one event should be created');
        System.assertEquals('Test Resource', createdEvents[0].Resource__c, 'Resource should match');
        System.assertEquals('12345', createdEvents[0].Client_Id__c, 'Client ID should match');
        System.assertEquals('Page View', createdEvents[0].Type__c, 'Type should match');
    }
    
    @IsTest
    static void testDoPostMissingFields() {
        // Test with missing fields (should still work as long as required fields aren't missing)
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        SiteEventController.EventWrapper testEvent = new SiteEventController.EventWrapper();
        testEvent.title = 'Minimal Event';
        testEvent.clientId = '67890';
        testEvent.type = 'Click';
        
        String jsonEvent = JSON.serialize(testEvent);
        
        req.requestURI = '/services/apexrest/event';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonEvent);
        
        RestContext.request = req;
        RestContext.response = res;
        
        System.Test.startTest();
        SiteEventController.doPost();
        System.Test.stopTest();
        
        // Verify the record was created with minimal fields
        List<Site_Event__c> createdEvents = [SELECT Id, Resource__c FROM Site_Event__c];
        System.assertEquals(1, createdEvents.size(), 'Event should be created with minimal fields');
        System.assertEquals('Minimal Event', createdEvents[0].Resource__c);
    }
}