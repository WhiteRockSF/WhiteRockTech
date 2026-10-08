@isTest 
private with sharing class LoginHistoriesControllerTest {
    @isTest 
    static void testAccountOpportunity(){    
        Account ac = new Account(
            Name = 'Test Account', 
            BillingStreet = '201 Donaghey Avenue', 
            BillingCity = 'Conway', 
            BillingState = 'AR', 
            BillingPostalCode = '72034', 
            BillingCountry = 'United States', 
            ShippingStreet = '201 Donaghey Avenue', 
            ShippingCity = 'Conway', 
            ShippingState = 'AR', 
            ShippingPostalCode = '72034', 
            ShippingCountry = 'United States');   
        insert ac;   
        
        Contact con = new Contact(
            FirstName = 'TEst',
            LastName = 'TEst',
            AccountId = ac.Id
        );   
        insert con;   

        Login_History__c h = new Login_History__c(
            Contact__c = con.Id,
            Account__c = ac.Id,
            Date__c = Date.today()
        );
        insert h;   
 
        PageReference testPage = Page.LoginHistories; 
        Test.setCurrentPage(testPage);
        testPage.getParameters().put('Id', String.valueOf(con.Id));
         
        ApexPages.StandardController sc = new  ApexPages.StandardController(con);     
        LoginHistoriesController ext = new LoginHistoriesController(sc);         
    } 
}