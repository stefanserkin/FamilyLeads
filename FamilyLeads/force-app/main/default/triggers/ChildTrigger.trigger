trigger ChildTrigger on Child__c (before insert) {

    ChildTriggerHandler.updateFamilyLead(Trigger.new);

}