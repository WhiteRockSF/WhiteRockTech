trigger TaskRayProjectTaskTrigger on TASKRAY__Project_Task__c (after update) {
    new TaskRayProjectTaskTriggerHandler().execute();
}