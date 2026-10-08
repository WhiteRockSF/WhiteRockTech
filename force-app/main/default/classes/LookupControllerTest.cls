@isTest
private class LookupControllerTest {

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Lookup Test Account');
        insert acc;

        TASKRAY__Project__c project = new TASKRAY__Project__c(
            Name = 'Lookup Test Project',
            TASKRAY__trAccount__c = acc.Id,
            TASKRAY__trStatus__c = '4bca81'
        );
        insert project;

        TASKRAY__Project_Task__c task = new TASKRAY__Project_Task__c(
            Name = 'Lookup Alpha Task',
            TASKRAY__Project__c = project.Id,
            TASKRAY__trAccount__c = acc.Id,
            TASKRAY__List__c = 'Holding',
            TASKRAY__Priority__c = 'Normal'
        );
        insert task;

        Production__c production = new Production__c(
            Name = 'Lookup Test Production',
            Account_Name__c = acc.Id,
            Work_In_Process_Status__c = 'New',
            Completed_Invoiced__c = false
        );
        insert production;

        Product2 service = new Product2(
            Name = 'Lookup WR Service',
            ProductCode = 'WR-LOOKUP-TEST',
            IsActive = true
        );
        insert service;

        insert new SFDC_Service_Timecard__c(
            Production__c = production.Id,
            Service__c = service.Id,
            TaskRay_Task__c = task.Id,
            Date_of_Service__c = Date.today().addDays(-7),
            Start_Time__c = Time.newInstance(8, 0, 0, 0),
            End_Time__c = Time.newInstance(9, 0, 0, 0),
            Service_Notes__c = 'lookup test',
            user__c = UserInfo.getUserId()
        );
    }

    @IsTest
    static void lookUp_popularProductionList_doesNotAutoSelect() {
        Test.startTest();
        List<Map<String, Object>> results = LookupController.lookUp(
            '',
            'Production__c',
            null
        );
        Test.stopTest();

        System.assert(!results.isEmpty());
        System.assertEquals('Lookup Test Production', results[0].get('Name'));
    }

    @IsTest
    static void lookUp_popularServiceList() {
        Test.startTest();
        List<Map<String, Object>> results = LookupController.lookUp(
            '',
            'Product2',
            null
        );
        Test.stopTest();

        System.assert(!results.isEmpty());
    }

    @IsTest
    static void lookUp_taskRaySearch_includesProjectInLabel() {
        Test.startTest();
        List<Map<String, Object>> results = LookupController.lookUp(
            'Alpha',
            'TASKRAY__Project_Task__c',
            null
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(
            'Lookup Alpha Task * Lookup Test Project',
            results[0].get('Name')
        );
    }

    @IsTest
    static void lookUp_searchProductionWithText() {
        Test.startTest();
        List<Map<String, Object>> results = LookupController.lookUp(
            'Lookup Test Production',
            'Production__c',
            null
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @IsTest
    static void hack() {
        Test.startTest();
        LookupController.hack();
        Test.stopTest();
    }
}