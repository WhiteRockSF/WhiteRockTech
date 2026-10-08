@isTest
public class MonthlySupportDocGenerationTest {
    @testSetup
    static void setupTestData() {
        // Create a TaskRay task with an Account Name
        TASKRAY__Project_Task__c task = new TASKRAY__Project_Task__c(
            Name = 'Monthly Support Task'
        );
        insert task;

        // Create a checklist group linked to the task
        TASKRAY__trChecklistGroup__c checklistGroup = new TASKRAY__trChecklistGroup__c(
            Name = 'Monthly Checklist',
            TASKRAY__TaskForGroup__c = task.Id
        );
        insert checklistGroup;

        // Create checklist items under that group
        List<TASKRAY__trChecklistItem__c> items = new List<TASKRAY__trChecklistItem__c>();
        for (Integer i = 0; i < 2; i++) {
            items.add(new TASKRAY__trChecklistItem__c(
                Name = 'Item ' + i,
                TASKRAY__trChecklistGroup__c = checklistGroup.Id,
                TASKRAY__trLongName__c = 'Long description ' + i,
                TASKRAY__Project_Task__c = task.Id
            ));
        }
        insert items;
    }

    @isTest
    static void testConstructor_ValidTaskId_WithChecklists() {
        // Retrieve the task created in @testSetup
        TASKRAY__Project_Task__c task = [SELECT Id FROM TASKRAY__Project_Task__c LIMIT 1];

        // Create standard controller and the actual controller
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(task);
        System.Test.startTest();
            MonthlySupportDocGenerationController controller = new MonthlySupportDocGenerationController(stdCtrl);
        System.Test.stopTest();


        // Assert that fields are populated correctly
        System.assertNotEquals(null, controller.monthValue, 'Month value should be set to current month');
        System.assertEquals('Customer', controller.companyName, 'Company name should be Customer');

        // Verify that checklists were queried
        System.assert(controller.checklists != null && !controller.checklists.isEmpty(), 'Checklists should be populated');
        System.assertEquals(1, controller.checklists.size(), 'There should be one checklist group');
        System.assert(controller.checklists[0].TASKRAY__TaskRay_Checklist_Items__r != null, 'Checklist items should be queried');
        System.assertEquals(2, controller.checklists[0].TASKRAY__TaskRay_Checklist_Items__r.size(), 'Two checklist items expected');
    }

    @isTest
    static void testSaveToRecord_Success() {
        // Get the existing task with checklist groups
        TASKRAY__Project_Task__c task = [SELECT Id, Account_Name__c FROM TASKRAY__Project_Task__c LIMIT 1];

        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(task);
        MonthlySupportDocGenerationController controller = new MonthlySupportDocGenerationController(stdCtrl);

        // Call saveToRecord()
        System.Test.startTest();
            PageReference resultPage = controller.saveToRecord();
        System.Test.stopTest();

        // Assert that a ContentVersion was inserted
        ContentVersion cv = [SELECT Id, Title, FirstPublishLocationId, VersionData
                             FROM ContentVersion
                             WHERE FirstPublishLocationId = :task.Id
                             ORDER BY CreatedDate DESC LIMIT 1];

        String expectedFileName = controller.monthValue + 'MonthlyReport_Customer.doc';
        System.assertEquals(expectedFileName, cv.Title, 'File name should match expected pattern');
        System.assertEquals(task.Id, cv.FirstPublishLocationId, 'File should be linked to the task');
        System.assert(cv.VersionData != null, 'File content should exist');

        // Assert redirect page is the task detail page
        System.assertEquals(true, ('/' + task.Id).contains(resultPage.getUrl()), 'Redirect should go to task record');
        System.assertEquals(true, resultPage.getRedirect(), 'Redirect should be set');
    }

}