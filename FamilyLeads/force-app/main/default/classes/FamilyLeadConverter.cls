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
        String strResult = '';

        // Create household account
        Account acc = new Account(Name='Household', recordTypeId=hhRecordTypeid);
        insert acc;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadToConvert.Id);
        lc.setAccountId(acc.Id);
        lc.setDoNotCreateOpportunity(true);

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
                ct.AccountId = acc.Id;
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

    public class ConvertRequest{
        
        @InvocableVariable
        public Lead lead;

        @InvocableVariable
        public List<Id> childrenIds;

        @InvocableVariable
        public Boolean convertChildren;

    }
    
    public class ConvertResult{

        @InvocableVariable
        public Id accountIdResult;

        @InvocableVariable
        public String saveResult;

    }
    
}
