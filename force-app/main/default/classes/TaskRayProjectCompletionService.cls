public without sharing class TaskRayProjectCompletionService {
    private static final String LIST_COMPLETED = 'Completed';
    private static final String LIST_NOT_PURSUED = 'Not Pursued';
    private static final String OUTBOUND_EMAIL = 'salesforce@whiterocktech.net';

    @TestVisible
    private static Integer emailsQueuedForTest = 0;

    public static void handleTaskListChanges(List<TASKRAY__Project_Task__c> newTasks, Map<Id, TASKRAY__Project_Task__c> oldMap) {
        Set<Id> projectIds = new Set<Id>();
        for (TASKRAY__Project_Task__c task : newTasks) {
            TASKRAY__Project_Task__c oldTask = oldMap == null ? null : oldMap.get(task.Id);
            if (task.TASKRAY__Project__c == null) {
                continue;
            }
            if (oldTask == null || task.TASKRAY__List__c != oldTask.TASKRAY__List__c) {
                projectIds.add(task.TASKRAY__Project__c);
            }
        }
        if (projectIds.isEmpty()) {
            return;
        }
        notifyCompletedProjects(projectIds, oldMap);
    }

    @TestVisible
    private static void notifyCompletedProjects(Set<Id> projectIds, Map<Id, TASKRAY__Project_Task__c> oldMap) {
        String joeEmail = getJoeEmail();
        if (String.isBlank(joeEmail)) {
            return;
        }

        List<TASKRAY__Project__c> projects = [
            SELECT Id, Name
            FROM TASKRAY__Project__c
            WHERE Id IN :projectIds
        ];
        if (projects.isEmpty()) {
            return;
        }

        Map<Id, List<TASKRAY__Project_Task__c>> tasksByProject = getQualifyingTasksByProject(projectIds);
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (TASKRAY__Project__c project : projects) {
            List<TASKRAY__Project_Task__c> qualifyingTasks = tasksByProject.get(project.Id);
            if (qualifyingTasks == null || qualifyingTasks.isEmpty()) {
                continue;
            }
            if (!allTasksTerminal(qualifyingTasks)) {
                continue;
            }
            if (wasAlreadyFullyComplete(qualifyingTasks, oldMap)) {
                continue;
            }

            emails.add(buildCompletionEmail(joeEmail, project));
        }

        if (emails.isEmpty()) {
            return;
        }

        emailsQueuedForTest += emails.size();
        sendEmailsSafely(emails);
    }

    private static void sendEmailsSafely(List<Messaging.SingleEmailMessage> emails) {
        try {
            Messaging.sendEmail(emails, false);
            return;
        } catch (Exception e) {
            // Retry without org-wide from address if OWEA is unavailable to the running user.
        }

        for (Messaging.SingleEmailMessage email : emails) {
            email.setOrgWideEmailAddressId(null);
        }
        try {
            Messaging.sendEmail(emails, false);
        } catch (Exception e) {
            // Org deliverability issues should not block the task update.
        }
    }

    private static Map<Id, List<TASKRAY__Project_Task__c>> getQualifyingTasksByProject(Set<Id> projectIds) {
        Map<Id, List<TASKRAY__Project_Task__c>> tasksByProject = new Map<Id, List<TASKRAY__Project_Task__c>>();
        for (TASKRAY__Project_Task__c task : [
            SELECT Id, TASKRAY__List__c, TASKRAY__Project__c, TASKRAY__trTaskGroup__r.Name
            FROM TASKRAY__Project_Task__c
            WHERE TASKRAY__Project__c IN :projectIds
              AND TASKRAY__trTaskGroup__c != null
        ]) {
            if (!isQualifyingTaskGroup(task.TASKRAY__trTaskGroup__r == null ? null : task.TASKRAY__trTaskGroup__r.Name)) {
                continue;
            }
            if (!tasksByProject.containsKey(task.TASKRAY__Project__c)) {
                tasksByProject.put(task.TASKRAY__Project__c, new List<TASKRAY__Project_Task__c>());
            }
            tasksByProject.get(task.TASKRAY__Project__c).add(task);
        }
        return tasksByProject;
    }

    private static Boolean wasAlreadyFullyComplete(
        List<TASKRAY__Project_Task__c> qualifyingTasks,
        Map<Id, TASKRAY__Project_Task__c> oldMap
    ) {
        for (TASKRAY__Project_Task__c task : qualifyingTasks) {
            TASKRAY__Project_Task__c oldTask = oldMap == null ? null : oldMap.get(task.Id);
            String priorList = oldTask == null ? task.TASKRAY__List__c : oldTask.TASKRAY__List__c;
            if (!isTerminalList(priorList)) {
                return false;
            }
        }
        return true;
    }

    private static Boolean isQualifyingTaskGroup(String groupName) {
        return String.isNotBlank(groupName) && !groupName.toLowerCase().contains('support');
    }

    private static Boolean allTasksTerminal(List<TASKRAY__Project_Task__c> tasks) {
        for (TASKRAY__Project_Task__c task : tasks) {
            if (!isTerminalList(task.TASKRAY__List__c)) {
                return false;
            }
        }
        return true;
    }

    private static Boolean isTerminalList(String listValue) {
        return listValue == LIST_COMPLETED || listValue == LIST_NOT_PURSUED;
    }

    private static Messaging.SingleEmailMessage buildCompletionEmail(String toAddress, TASKRAY__Project__c project) {
        String projectUrl = URL.getOrgDomainUrl().toExternalForm() + '/' + project.Id;
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        applyOrgWideFrom(email);
        email.setToAddresses(new List<String>{ toAddress });
        email.setSubject(project.Name + ' Completed');
        email.setPlainTextBody(
            'All tasks on this project have now been completed. Please notify the customer that they will transition to support and notify Mike of the completion for billing.\n\n'
            + projectUrl
        );
        email.setSaveAsActivity(false);
        return email;
    }

    private static String getJoeEmail() {
        List<User> joeUsers = [
            SELECT Email
            FROM User
            WHERE IsActive = true
              AND FirstName = 'Joe'
              AND Email != null
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return joeUsers.isEmpty() ? null : joeUsers[0].Email;
    }

    private static void applyOrgWideFrom(Messaging.SingleEmailMessage email) {
        List<OrgWideEmailAddress> rows = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :OUTBOUND_EMAIL
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            email.setOrgWideEmailAddressId(rows[0].Id);
        }
    }
}