global with sharing class MatchingContactFinder {

    @InvocableMethod(label='Finding Matching Contacts' description='Returns potential matching Contacts for a Lead' category='Lead')
    public static List<Result> findMatchingContacts(List<Request> request) {
        Lead ld = request.get(0).lead;

        List<Contact> lstMatchingContacts = [SELECT Id, FirstName, LastName, Email, Phone, Birthdate
                                               FROM Contact
                                              WHERE LastName = :ld.LastName
                                                AND (FirstName LIKE :ld.FirstName
                                                 OR npe01__HomeEmail__c LIKE :ld.Email
                                                 OR npe01__WorkEmail__c LIKE :ld.Email
                                                 OR npe01__AlternateEmail__c LIKE :ld.Email
                                                 OR HomePhone = :ld.Phone)];

        // Parse output
        Result result = new Result();
        result.lstMatchingContacts = lstMatchingContacts;
        List<Result> resultList = new List<Result>();
        resultList.add(result);
        return resultList;

    }

    public class Request {

        @invocableVariable(required=true)
        public Lead lead;

    }

    public class Result {

        @invocableVariable
        public List<Contact> lstMatchingContacts;

    }
    
}