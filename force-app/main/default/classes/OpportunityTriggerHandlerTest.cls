@isTest 
public with sharing class OpportunityTriggerHandlerTest {

    @isTest
    static void testBeforeUpdateTrigger() {
       
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        Product2 prodParent = new Product2(Name = 'Account Sprint', IsActive = true);
        insert prodParent;
        Product2 prodChild = new Product2(Name = 'Record Types', IsActive = true, Parent_Service__c = prodParent.Id);
        insert prodChild;

        ID standardPBID = Test.getStandardPricebookId();
        PricebookEntry pbeParent = new PricebookEntry(Pricebook2Id = standardPBID, Product2Id = prodParent.Id, UnitPrice = 10000, IsActive = true );
        PricebookEntry pbeChild = new PricebookEntry(Pricebook2Id = standardPBID, Product2Id = prodChild.Id, UnitPrice = 10000, IsActive = true );
        insert new List<PricebookEntry> {pbeParent,pbeChild};
         
        OpportunityLineItem oliParent = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prodParent.Id,
            PricebookEntryId = pbeParent.Id,
            Quantity = 1,
            UnitPrice = 100,
            Estimated_Start_Date__c = Date.today(),
            Estimated_End_Date__c = Date.today().addDays(10),
            Estimated_Hours_to_Complete__c = 10
        );
        OpportunityLineItem oliChild  = new OpportunityLineItem(
            OpportunityId = opp.Id,
            Product2Id = prodChild.Id,
            PricebookEntryId = pbeChild.Id,
            Quantity = 1,
            UnitPrice = 100,
            Estimated_Start_Date__c = Date.today(),
            Estimated_End_Date__c = Date.today().addDays(10),
            Estimated_Hours_to_Complete__c = 10
        );
        insert new List<OpportunityLineItem> {oliParent,oliChild};
        
        opp.StageName = 'Win & Transition';
        update opp;

        List<TASKRAY__Project__c> projects = [SELECT Id, TASKRAY__trOpportunity__c FROM TASKRAY__Project__c WHERE TASKRAY__trOpportunity__c = :opp.Id];
        System.assertEquals(1, projects.size(), 'One TASKRAY__Project__c should have been created.');

        List<TASKRAY__trTaskGroup__c> taskGroups = [SELECT Id, TASKRAY__Project__c FROM TASKRAY__trTaskGroup__c WHERE TASKRAY__Project__c IN :projects];
        System.assertEquals(1, taskGroups.size(), 'One TASKRAY__trTaskGroup__c should have been created.');

        List<TASKRAY__Project_Task__c> projectTasks = [SELECT Id, TASKRAY__Project__c FROM TASKRAY__Project_Task__c WHERE TASKRAY__Project__c IN :projects];
        System.assertEquals(2, projectTasks.size(), 'One TASKRAY__Project_Task__c should have been created.');
        
    }
}