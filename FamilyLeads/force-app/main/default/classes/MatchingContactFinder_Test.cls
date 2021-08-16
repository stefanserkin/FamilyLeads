@isTest
public class MatchingContactFinder_Test {
    
    @isTest
    static void testReturnDuplicate() {
        Id hhRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('HH_Account').getRecordTypeId();
        Id flRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Family_Lead_Record_Type').getRecordTypeId();

        Account acc = new Account(Name='Ordonez Household',RecordTypeId=hhRTId);
        insert acc;

        Contact ct = new Contact(FirstName='Rey',LastName='Ordonez',Email='rey@mets.com',AccountId=acc.Id);
        insert ct;

        Lead ld = new Lead(RecordTypeId=flRTId,FirstName='Rey',LastName='Ordonez',Email='rey@mets.com',Company='Individual');
        insert ld;

        Test.startTest();
        List<MatchingContactFinder.Result> resultList; 
        resultList = new List<MatchingContactFinder.Result>();
        MatchingContactFinder.Request request;
        request = new MatchingContactFinder.Request();
        request.lead = ld;
        resultList = MatchingContactFinder.findMatchingContacts(
            new List<MatchingContactFinder.Request>{ request }
        );
        Test.stopTest();

        List<Contact> lstMatchingContacts = resultList.get(0).lstMatchingContacts;
        String matchingLastName = lstMatchingContacts.get(0).LastName;

        System.assertEquals(true, !lstMatchingContacts.isEmpty(), 
            'Found no matches'
        );
        System.assertEquals(ct.LastName, matchingLastName,
            'First name does not match'
        );

    }
}