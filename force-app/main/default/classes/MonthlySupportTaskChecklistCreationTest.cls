@isTest
public with sharing class MonthlySupportTaskChecklistCreationTest {
    

    @testSetup
    static void setupTestData() {
        // MokUp TaskRay tasks to be referenced by the checklist groups
        List<TASKRAY__Project_Task__c> tasks = new List<TASKRAY__Project_Task__c>{
            new TASKRAY__Project_Task__c(Name = 'Support Task 1')
        };
        insert tasks;
    }

    @IsTest
    static void testCreateChecklistsSuccess() {
        // Retrieve Ids of the tasks created in testSetup
        List<TASKRAY__Project_Task__c> tasks = [SELECT Id FROM TASKRAY__Project_Task__c];
        List<Id> taskIds = new List<Id>();
        for (TASKRAY__Project_Task__c t : tasks) {
            taskIds.add(t.Id);
        }

        MonthlySupportTaskChecklistCreation.ChecklistsCreationActionRequest request = new MonthlySupportTaskChecklistCreation.ChecklistsCreationActionRequest();
        request.tasksIds = taskIds;   // Assuming the class has a public List<Id> field
        List<MonthlySupportTaskChecklistCreation.ChecklistsCreationActionRequest> requestList = new List<MonthlySupportTaskChecklistCreation.ChecklistsCreationActionRequest>{ request };

        //Perform test
        System.Test.startTest();
            List<MonthlySupportTaskChecklistCreation.ActionResult> results = MonthlySupportTaskChecklistCreation.createChecklistsWithItems(requestList);
        System.Test.stopTest();

        // Assert one result returned and success flag true
        System.assertEquals(1, results.size(), 'Exactly one result should be returned');
        System.assertEquals(true, results[0].creationSucceeded, 'Creation should succeed');

        
        List<TASKRAY__trChecklistGroup__c> createdGroups = [
            SELECT Id, Name, TASKRAY__TaskForGroup__c
            FROM TASKRAY__trChecklistGroup__c
            WHERE TASKRAY__TaskForGroup__c IN :taskIds
        ];

        List<TASKRAY__trChecklistItem__c> createdItems = [
            SELECT Id, Name, TASKRAY__trChecklistGroup__c
            FROM TASKRAY__trChecklistItem__c
            WHERE TASKRAY__trChecklistGroup__c IN :createdGroups
        ];

        System.assertEquals(4, createdGroups.size(), 'Should create 4 checklist groups');        
        System.assertEquals(27, createdItems.size(), 'Should create 27 checklist items');
    }

}