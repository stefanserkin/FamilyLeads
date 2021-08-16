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
        for (List<Lead> lstLeads : [SELECT Id, Family_Lead__c FROM Lead WHERE Id IN :setLeadIds])
        {
            for (Lead ld : lstLeads) {
                if (ld.Family_Lead__c != true) {
                    ld.Child1_First_Name__c = 'FamilyLead';
                    lstLeadsToUpdate.add(ld);
                }
            }
        }
        if (!lstLeadsToUpdate.isEmpty()) {
            update lstLeadsToUpdate;
        }
    }
    
}