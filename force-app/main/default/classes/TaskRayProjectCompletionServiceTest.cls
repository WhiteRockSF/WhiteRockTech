@isTest
private class TaskRayProjectCompletionServiceTest {
    private static void ensureJoeUserExists() {
        List<User> existing = [
            SELECT Id
            FROM User
            WHERE IsActive = true
              AND FirstName = 'Joe'
              AND Email != null
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return;
        }

        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User joe = new User(
            FirstName = 'Joe',
            LastName = 'Completion Test',
            Email = 'joe.completion.test@example.com',
            Username = 'joe.completion.' + System.currentTimeMillis() + '@example.com.test',
            Alias = 'joect',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert joe;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Separate setup DML from non-setup DML in the calling test.
        }
    }

    @isTest
    static void sendsEmailWhenLastQualifyingTaskCompletes() {
        ensureJoeUserExists();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account acc = new Account(Name = 'TaskRay Completion Account');
            insert acc;

            TASKRAY__Project__c project = new TASKRAY__Project__c(
                Name = 'Completion Test Project',
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__trStatus__c = '4bca81'
            );
            insert project;

            TASKRAY__trTaskGroup__c deliveryGroup = new TASKRAY__trTaskGroup__c(
                Name = 'Delivery Group',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id
            );
            TASKRAY__trTaskGroup__c supportGroup = new TASKRAY__trTaskGroup__c(
                Name = 'Support Group',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id
            );
            insert new List<TASKRAY__trTaskGroup__c>{ deliveryGroup, supportGroup };

            TASKRAY__Project_Task__c openTask = new TASKRAY__Project_Task__c(
                Name = 'Open Delivery Task',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__trTaskGroup__c = deliveryGroup.Id,
                TASKRAY__List__c = 'Story Board',
                TASKRAY__Priority__c = 'Normal'
            );
            TASKRAY__Project_Task__c supportTask = new TASKRAY__Project_Task__c(
                Name = 'Support Task',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__trTaskGroup__c = supportGroup.Id,
                TASKRAY__List__c = 'Story Board',
                TASKRAY__Priority__c = 'Normal'
            );
            TASKRAY__Project_Task__c noGroupTask = new TASKRAY__Project_Task__c(
                Name = 'No Group Task',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__List__c = 'Story Board',
                TASKRAY__Priority__c = 'Normal'
            );
            insert new List<TASKRAY__Project_Task__c>{ openTask, supportTask, noGroupTask };

            TaskRayProjectCompletionService.emailsQueuedForTest = 0;

            System.Test.startTest();
            openTask.TASKRAY__List__c = 'Completed';
            update openTask;
            System.Test.stopTest();

            System.assert(
                TaskRayProjectCompletionService.emailsQueuedForTest > 0,
                'Email should queue when the last qualifying task completes.'
            );
        }
    }

    @isTest
    static void doesNotSendWhenQualifyingTaskStillOpen() {
        ensureJoeUserExists();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account acc = new Account(Name = 'TaskRay Open Account');
            insert acc;

            TASKRAY__Project__c project = new TASKRAY__Project__c(
                Name = 'Open Tasks Project',
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__trStatus__c = '4bca81'
            );
            insert project;

            TASKRAY__trTaskGroup__c deliveryGroup = new TASKRAY__trTaskGroup__c(
                Name = 'Delivery Group',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id
            );
            insert deliveryGroup;

            TASKRAY__Project_Task__c openTask = new TASKRAY__Project_Task__c(
                Name = 'Still Open Task',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__trTaskGroup__c = deliveryGroup.Id,
                TASKRAY__List__c = 'Story Board',
                TASKRAY__Priority__c = 'Normal'
            );
            TASKRAY__Project_Task__c doneTask = new TASKRAY__Project_Task__c(
                Name = 'Done Task',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__trTaskGroup__c = deliveryGroup.Id,
                TASKRAY__List__c = 'Completed',
                TASKRAY__Priority__c = 'Normal'
            );
            insert new List<TASKRAY__Project_Task__c>{ openTask, doneTask };

            TaskRayProjectCompletionService.emailsQueuedForTest = 0;

            System.Test.startTest();
            doneTask.TASKRAY__List__c = 'Not Pursued';
            update doneTask;
            System.Test.stopTest();

            System.assertEquals(
                0,
                TaskRayProjectCompletionService.emailsQueuedForTest,
                'Email should not queue while a qualifying task is still open.'
            );
        }
    }

    @isTest
    static void doesNotResendWhenProjectWasAlreadyComplete() {
        ensureJoeUserExists();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account acc = new Account(Name = 'TaskRay Already Complete Account');
            insert acc;

            TASKRAY__Project__c project = new TASKRAY__Project__c(
                Name = 'Already Complete Project',
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__trStatus__c = '4bca81'
            );
            insert project;

            TASKRAY__trTaskGroup__c deliveryGroup = new TASKRAY__trTaskGroup__c(
                Name = 'Delivery Group',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id
            );
            insert deliveryGroup;

            TASKRAY__Project_Task__c doneTask = new TASKRAY__Project_Task__c(
                Name = 'Done Task',
                TASKRAY__Project__c = project.Id,
                TASKRAY__trAccount__c = acc.Id,
                TASKRAY__trTaskGroup__c = deliveryGroup.Id,
                TASKRAY__List__c = 'Completed',
                TASKRAY__Priority__c = 'Normal'
            );
            insert doneTask;

            TaskRayProjectCompletionService.emailsQueuedForTest = 0;

            System.Test.startTest();
            doneTask.TASKRAY__List__c = 'Not Pursued';
            update doneTask;
            System.Test.stopTest();

            System.assertEquals(
                0,
                TaskRayProjectCompletionService.emailsQueuedForTest,
                'Email should not resend when the project was already fully complete.'
            );
        }
    }
}