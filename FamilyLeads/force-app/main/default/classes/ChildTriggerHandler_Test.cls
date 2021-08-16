@isTest
public class ChildTriggerHandler_Test {
    
    @isTest
    static void testChangeToFamilyLead() {

        Lead ld = new Lead(FirstName='Lead',LastName='Test',Company='Individual');
        insert ld;

        List<Child__c> lstChildren = new List<Child__c>();
        for (Integer i = 0; i < 5; i++) {
            Child__c ch = new Child__c();
            ch.First_Name__c = 'Child' + String.valueOf(i);
            ch.Last_Name__c  = 'Test';
            ch.Parent__c     = ld.Id;
            lstChildren.add(ch);
        }

        Test.startTest();
        Database.SaveResult[] srList = Database.insert(lstChildren, false);
        Test.stopTest();

        Lead ldToVerify = [SELECT Id, Family_Lead__c FROM Lead WHERE Id = :ld.Id LIMIT 1];

        for (Database.SaveResult sr : srList) {
            System.assert(sr.isSuccess());
        }
        System.assertEquals(true, ldToVerify.Family_Lead__c,
            'Unexpected family lead value');
        
    }
}