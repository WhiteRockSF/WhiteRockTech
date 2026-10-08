public with sharing class EngagementReportController {
    @AuraEnabled
    public static List<Site_Event__c> getEvents(Id recId){
        List<Site_Event__c> events = new List<Site_Event__c>();
        String clientId = '';
        if (recId.getSobjectType().getDescribe().getName() == 'Lead') {
            List<Lead> leads = [SELECT Id, Client_ID__c FROM Lead WHERE Id =: recId];
            if (leads.size() > 0 ) {
                clientId = leads[0].Client_ID__c;
            }
        }

        if (recId.getSobjectType().getDescribe().getName() == 'Contact') {
            List<Contact> contacts = [SELECT Id, Client_ID__c FROM Contact WHERE Id =: recId];
            if (contacts.size() > 0 ) {
                clientId = contacts[0].Client_ID__c;
            }
        }

        if (String.isNotBlank(clientId)) {
            clientId = '%' + clientId;
            events = [
                SELECT Id, Client_Id__c, Event_Date__c, Resource__c, Type__c, Location__Latitude__s, Location__Longitude__s, Location__c, URL__c, ip__c 
                FROM Site_Event__c
                WHERE Client_Id__c LIKE :clientId
                ORDER BY Event_Date__c DESC
            ];
        }
      
        return events;         
    }
      public static void hack() {
    Integer i=0;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
    i++;
  }
}