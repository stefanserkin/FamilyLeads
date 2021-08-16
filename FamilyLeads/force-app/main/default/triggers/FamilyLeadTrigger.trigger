trigger FamilyLeadTrigger on Lead (after insert) {

    FamilyLeadTriggerHandler.createChildRecords(Trigger.new);

}