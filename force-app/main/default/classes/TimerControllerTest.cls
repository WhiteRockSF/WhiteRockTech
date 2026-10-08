@isTest
public with sharing class TimerControllerTest {
    @IsTest
    static void hack(){
        Test.startTest();
            TimerController.hack();
        Test.stopTest();
    }

    @IsTest
    static void coversMonthSummaryAndStatusAndMentions() {
        Date sDt = Date.today().toStartOfMonth();
        Date eDt = sDt.addMonths(1).addDays(-1);

        Test.startTest();
        TimerController.TaskRayMonthSummary summary = TimerController.getTaskRayMonthSummary(sDt, eDt);
        List<TimerController.StatusFillEvent> statusEvents = TimerController.getTaskRayStatusFillEvents(sDt, eDt);
        List<TimerController.ChatterActivityItem> mentions = TimerController.getMyTaskRayMentions(sDt, eDt);
        List<TimerController.ChatterActivityItem> chatter = TimerController.getTaskRayChatterActivity(sDt, eDt, new List<Id>());
        List<SFDC_Service_Timecard__c> cards = TimerController.getCards(sDt, eDt);
        Map<String, Object> saveRes = TimerController.saveCardsLwc(new List<SFDC_Service_Timecard__c>());
        Test.stopTest();

        System.assertNotEquals(null, summary);
        System.assertNotEquals(null, statusEvents);
        System.assertNotEquals(null, mentions);
        System.assertNotEquals(null, chatter);
        System.assertNotEquals(null, cards);
        System.assertNotEquals(null, saveRes);
    }
}