/*
 * Created by Stefan Serkin on August 9, 2021
 * */
global with sharing class FamilyLeadConverter {

    private static Id hhRecordTypeid = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('HH_Account').getRecordTypeId();
    private static Id accountId;
    private static Boolean isMerge = false;

    @InvocableMethod(label='Convert Family Lead' description='Converts a Lead record and related children records' category='Lead')
    public static List<ConvertResult> convertLead(List<ConvertRequest> request) {
        // Assign values from Flow
        Lead leadToConvert         = request.get(0).lead;
        List<Id> lstChildrenIds    = request.get(0).childrenIds;
        Boolean convertChildren    = request.get(0).convertChildren;
        Id matchingContactId       = request.get(0).matchingContactId;
        Id matchingAccountId       = request.get(0).matchingAccountId;

        Map<Id, Contact> mapContactsInAccount = new Map<Id, Contact>();
        String strResult = '';

        // Set up values for conversion
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadToConvert.Id);
        lc.setDoNotCreateOpportunity(true);

        // If a matching contact was selected, find its Account.
        // Otherwise, create a new Household Account to associate
        if (matchingContactId != null) {
            isMerge = true;
            accountId = matchingAccountId;
            Account accWithContacts = [SELECT Id, 
                                              (SELECT Id, FirstName, LastName 
                                                 FROM Contacts) 
                                         FROM Account 
                                        WHERE Id = :matchingAccountId 
                                        LIMIT 1];
            // Put Contacts from household in map to check against child records
            for (Contact ct : accWithContacts.Contacts) {
                mapContactsInAccount.put(ct.Id, ct);
            }
            lc.setContactId(matchingContactId);
        } else {
            Account acc = createNewAccount();
            accountId = acc.Id;
        }
        lc.setAccountId(accountId);

        // Get converted status for lead record type
        String SObjectType  = String.valueOf(leadToConvert.getSObjectType());
        Id leadRecordTypeId = leadToConvert.RecordTypeId;
        String closedStatus = getClosedStatusForRecordTypeId(SObjectType, leadRecordTypeId);
        lc.setConvertedStatus(closedStatus);

        // Convert lead
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (lcr.isSuccess()) {
            strResult = 'Success!';
        } else {
            strResult = 'Uh oh. This conversion was not successful';
        }

        // Create a Contact for each child to be converted
        List<Contact> lstChildCtsToInsert = new List<Contact>();
        if (convertChildren && !lstChildrenIds.isEmpty()) {
            lstChildCtsToInsert = createContactsForChildren(lstChildrenIds, mapContactsInAccount);
        }

        if (!lstChildCtsToInsert.isEmpty()) {
            try {
                insert lstChildCtsToInsert;
            } catch (DmlException e) {
                System.debug('Failed to create child records: ' + e.getMessage());
            }
        }

        // Parse output
        ConvertResult result   = new ConvertResult();
        result.saveResult      = strResult;
        result.accountIdResult = lcr.getAccountId();
        List<ConvertResult> resultList = new List<ConvertResult>();
        resultList.add(result);
        return resultList;

    }

    public class ConvertRequest {
        
        @InvocableVariable
        public Lead lead;

        @InvocableVariable
        public List<Id> childrenIds;

        @InvocableVariable
        public Boolean convertChildren;

        @InvocableVariable
        public Id matchingContactId;

        @InvocableVariable
        public Id matchingAccountId;

    }
    
    public class ConvertResult {

        @InvocableVariable
        public Id accountIdResult;

        @InvocableVariable
        public String saveResult;

    }

    private static String getClosedStatusForRecordTypeId(String SObjectType, Id recordTypeId) {
        Status_Mapping__mdt sm = [SELECT Id, ClosedStatus__c 
                                    FROM Status_Mapping__mdt 
                                   WHERE SObjectType__c = :SObjectType
                                     AND RecordTypeId__c = :recordTypeId
                                   LIMIT 1];
        if (sm != null) {
            return sm.ClosedStatus__c;
        } else {
            return 'Closed - Converted';
        }
    }

    private static Account createNewAccount() {
        Account acc = new Account(Name='Household', recordTypeId=hhRecordTypeid);
        insert acc;
        return acc;
    }

    private static List<Contact> createContactsForChildren(List<Id> lstChildrenIds, Map<Id, Contact> mapContactsInAccount) {
        List<Contact> lstChildCtsToInsert = new List<Contact>();

        List<Child__c> lstChildren = [SELECT Id, First_Name__c, Last_Name__c, Birthdate__c, Interests__c 
                                        FROM Child__c 
                                       WHERE Id IN :lstChildrenIds 
                                       LIMIT 10000];

        for (Child__c ch : lstChildren) {
            Boolean foundMatchingContact = false;
            // If merging, skip any children with matching contacts already in household
            if (isMerge) {
                for (Contact ct : mapContactsInAccount.values()) {
                    if (ct.FirstName.equals(ch.First_Name__c) && ct.LastName.equals(ch.Last_Name__c)) {
                        foundMatchingContact = true;
                    }
                }
            }
            if (foundMatchingContact) {
                continue;
            }

            Contact ct = new Contact();
            ct.AccountId = accountId;
            ct.FirstName = ch.First_Name__c;
            ct.LastName  = ch.Last_Name__c;
            ct.Birthdate = ch.Birthdate__c;
            ct.Program_Interests__c = ch.Interests__c;
            lstChildCtsToInsert.add(ct);
        }

        return lstChildCtsToInsert;
    }
    
}