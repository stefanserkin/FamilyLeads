public with sharing class ChildTriggerHandler {

    public static void updateFamilyLead(List<Child__c> lstNewChildren) {
        System.debug('Entered updateFamilyLead method');

        List<Lead> lstLeadsToUpdate = new List<Lead>();

        Set<Id> setLeadIds = new Set<Id>();
        for (Child__c ch : lstNewChildren) {
            if (ch.Parent__c != null) {
                setLeadIds.add(ch.Parent__c);
            }
        }
        System.debug('setLeadIds has ' + setLeadIds.size() + ' entries');

        // If family lead is not already checked, check it
        for (List<Lead> lstLeads : [SELECT Id, Family_Lead__c FROM Lead WHERE Id IN :setLeadIds])
        {
            for (Lead ld : lstLeads) {
                System.debug('BEFORE: Family Lead is set to ' + ld.Family_Lead__c);
                if (ld.Family_Lead__c != true) {
                    ld.Child1_First_Name__c = 'FamilyLead';
                    lstLeadsToUpdate.add(ld);
                }
                System.debug('AFTER: Family Lead is set to ' + ld.Family_Lead__c);
            }
        }
        System.debug('lstLeadsToUpdate has ' + lstLeadsToUpdate.size() + ' entries');
        if (!lstLeadsToUpdate.isEmpty()) {
            update lstLeadsToUpdate;
        }
    }
    
}