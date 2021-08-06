public with sharing class ChildTriggerHandler {

    public static void updateFamilyLead(List<Child__c> lstNewChildren) {

        List<Lead> lstLeadsToUpdate = new List<Lead>();

        Set<Id> setLeadIds = new Set<Id>();
        for (Child__c ch : lstNewChildren) {
            if (ch.Parent__c != null) {
                setLeadIds.add(ch.Parent__c);
            }
        }
        // If family lead is not already checked, check it
        for (Lead l : [SELECT Id, Family_Lead__c FROM Lead WHERE Id IN :setLeadIds])
        {
            if (!l.Family_Lead__c) {
                l.Child1_First_Name__c = 'FamilyLead';
            }
        }

        update lstLeadsToUpdate;

    }
    
}