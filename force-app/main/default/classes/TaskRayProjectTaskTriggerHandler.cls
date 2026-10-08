public with sharing class TaskRayProjectTaskTriggerHandler {
    public void execute() {
        if (Trigger.operationType == TriggerOperation.AFTER_UPDATE) {
            TaskRayProjectCompletionService.handleTaskListChanges(
                (List<TASKRAY__Project_Task__c>) Trigger.new,
                (Map<Id, TASKRAY__Project_Task__c>) Trigger.oldMap
            );
        }
    }
}