trigger FamilyLeadTrigger on Lead (after insert, after update) {

    FamilyLeadTriggerHandler.createChildRecords(Trigger.new);

}