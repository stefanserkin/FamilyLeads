/*
 * Created by Stefan Serkin on July 18, 2021
 * */
global with sharing class FamilyLeadConverter {

    private static Id hhRecordTypeid = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('HH_Account').getRecordTypeId();

    @InvocableMethod(label='Convert Family Lead' description='Converts a Lead record and related children records' category='Lead')
    public static List<ConvertResult> convertLead(List<ConvertRequest> request) {
        // Assign values from Flow
        Lead leadToConvert         = request.get(0).lead;
        List<Id> lstChildrenIds    = request.get(0).childrenIds;
        Boolean convertChildren    = request.get(0).convertChildren;
        Id matchingContactId       = request.get(0).matchingContactId;
        Id accountId;
        String strResult = '';

        System.debug('leadToConvert: ' + leadToConvert.Id);
        System.debug('Number of lstChildrenIds: ' + lstChildrenIds.size());
        System.debug('convertChildren: ' + convertChildren);
        System.debug('matchingContactId: ' + matchingContactId);

        // Set up values for conversion
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadToConvert.Id);
        lc.setDoNotCreateOpportunity(true);

        // If a matching contact was selected, find its Account.
        // Otherwise, create a new Household Account to associate
        if (matchingContactId != null) {
            Contact ct = [SELECT Id, FirstName, LastName, AccountId FROM Contact WHERE Id = :matchingContactId LIMIT 1];
            accountId = ct.AccountId;
            lc.setAccountId(accountId);
            lc.setContactId(ct.Id);
        } else {
            Account acc = createNewAccount();
            accountId = acc.Id;
            lc.setAccountId(accountId);
        }

        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);

        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (lcr.isSuccess()) {
            strResult = 'Success!';
        } else {
            strResult = 'Uh oh. This conversion was not successful';
        }

        List<Contact> lstChildCtsToInsert = new List<Contact>();
        List<Child__c> lstChildren = new List<Child__c>();

        if (convertChildren && !lstChildrenIds.isEmpty()) {
            lstChildren = [SELECT Id, First_Name__c, Last_Name__c, Birthdate__c, Interests__c 
                             FROM Child__c 
                            WHERE Parent__c = :leadToConvert.Id
                              AND Id IN :lstChildrenIds 
                            LIMIT 10000];

            for (Child__c ch : lstChildren) {
                Contact ct = new Contact();
                ct.AccountId = accountId;
                ct.FirstName = ch.First_Name__c;
                ct.LastName = ch.Last_Name__c;
                ct.Birthdate = ch.Birthdate__c;
                ct.Program_Interests__c = ch.Interests__c;
                lstChildCtsToInsert.add(ct);
            }
        }

        if (!lstChildCtsToInsert.isEmpty()) {
            try {
                insert lstChildCtsToInsert;
            } catch (DmlException e) {
                System.debug('Failed to create child records: ' + e.getMessage());
            }
        }

        // Parse output
        ConvertResult result = new ConvertResult();
        result.saveResult = strResult;
        result.accountIdResult = lcr.getAccountId();
        List<ConvertResult> resultList = new List<ConvertResult>();
        resultList.add(result);
        return resultList;

    }

    private static Account createNewAccount() {
        Account acc = new Account(Name='Household', recordTypeId=hhRecordTypeid);
        insert acc;
        return acc;
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

    }
    
    public class ConvertResult {

        @InvocableVariable
        public Id accountIdResult;

        @InvocableVariable
        public String saveResult;

    }
    
}
