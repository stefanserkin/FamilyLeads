/*
 * Created by Stefan Serkin on August 9, 2021
 * */
global with sharing class FamilyLeadConverter {

    private static Id hhRecordTypeid = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('HH_Account').getRecordTypeId();
    private static Id accountId;
    private static Boolean isMerge = false;
    private static List<Contact> lstChildCtsToInsert = new List<Contact>();
    private static List<Child__c> lstChildrenOfContacts = new List<Child__c>();
    private static Map<Id, Id> mapChildIdToConvertedContactId = new Map<Id, Id>();
    private static Map<Id, Contact> mapContactsInAccount;

    @InvocableMethod(label='Convert Family Lead' description='Converts a Lead record and related children records' category='Lead')
    public static List<ConvertResult> convertLead(List<ConvertRequest> request) {
        // Assign values from Flow
        Lead leadToConvert         = request.get(0).lead;
        List<Id> lstChildrenIds    = request.get(0).childrenIds;
        Boolean convertChildren    = request.get(0).convertChildren;
        Id matchingContactId       = request.get(0).matchingContactId;
        Id matchingAccountId       = request.get(0).matchingAccountId;
        String strResult = '';

        // Set up values for conversion
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadToConvert.Id);
        lc.setDoNotCreateOpportunity(true);

        // If a matching contact was selected, find its Account.
        // Otherwise, create a new Household Account to associate
        if (matchingContactId != null && matchingAccountId != null) {
            isMerge = true;
            mapContactsInAccount = new Map<Id, Contact>();
            accountId = getAccountWithContacts(matchingAccountId).Id;
            lc.setContactId(matchingContactId);
        } else {
            Account acc = createNewAccount();
            accountId = acc.Id;
        }
        lc.setAccountId(accountId);

        // Get converted status for lead record type
        String sObjectType  = String.valueOf(leadToConvert.getSObjectType());
        Id leadRecordTypeId = leadToConvert.RecordTypeId;
        String closedStatus = getClosedStatusForRecordTypeId(sObjectType, leadRecordTypeId);
        lc.setConvertedStatus(closedStatus);

        // Convert lead
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        if (lcr.isSuccess()) {
            strResult = 'Success!';
        } else {
            strResult = 'Uh oh. This conversion was not successful';
        }

        // Create a Contact for each child to be converted
        if (convertChildren && !lstChildrenIds.isEmpty()) {
            lstChildCtsToInsert.addAll(createContactsForChildren(lstChildrenIds, mapContactsInAccount));
        }
        if (!lstChildCtsToInsert.isEmpty()) {
            try {
                upsert lstChildCtsToInsert;
            } catch (DmlException e) {
                System.debug('Failed to upsert child records: ' + e.getMessage());
            }
        }
        // Add Child and Contact Ids to map
        for (Contact chCt : lstChildCtsToInsert) {
            if (!String.isBlank(chCt.Related_Lead_ID__c)) {
                mapChildIdToConvertedContactId.put(chCt.Related_Lead_ID__c, chCt.Id);
            }
        }
        // Mark children converted
        if (!mapChildIdToConvertedContactId.isEmpty() && !lstChildrenOfContacts.isEmpty()) {
            markChildrenConverted(lstChildrenOfContacts, mapChildIdToConvertedContactId);
        }
    
        // Parse output
        ConvertResult result = new ConvertResult();
        result.saveResult = strResult;
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

    private static String getClosedStatusForRecordTypeId(String sObjectType, Id recordTypeId) {
        String closedStatus = '';
        List<Status_Mapping__mdt> smList = Status_Mapping__mdt.getAll().values();
        for (Status_Mapping__mdt sm : smList) {
            if (sm.RecordTypeId__c == recordTypeId) {
                closedStatus = sm.ClosedStatus__c;
            }
        }
        return closedStatus;
    }

    private static Account createNewAccount() {
        Account acc = new Account(Name='Household', recordTypeId=hhRecordTypeid);
        try {
            insert acc;
        } catch(DmlException e) {
            System.debug('There was an error inserting the new account: ' + e.getMessage());
        }
        return acc;
    }

    private static Account getAccountWithContacts(Id accountId) {
        Account accWithContacts = [SELECT Id, 
                                          (SELECT Id, FirstName, LastName, Program_Interests__c,
                                                  Birthdate, ssfl_Gender__c, Related_Lead_ID__c 
                                             FROM Contacts) 
                                     FROM Account 
                                    WHERE Id = :accountId 
                                     WITH SECURITY_ENFORCED
                                    LIMIT 1];
        // Put Contacts from household in map to check against child records
        for (Contact ct : accWithContacts.Contacts) {
            mapContactsInAccount.put(ct.Id, ct);
        }
        return accWithContacts;
    }

    private static List<Contact> createContactsForChildren(List<Id> lstChildrenIds, Map<Id, Contact> mapContactsInAccount) {
        List<Contact> lstContactResults = new List<Contact>();
        List<Child__c> lstChildren = [SELECT Id, First_Name__c, Last_Name__c, Birthdate__c, Interests__c, 
                                             Gender__c, Converted_Contact__c, IsConverted__c 
                                        FROM Child__c 
                                       WHERE Id IN :lstChildrenIds 
                                        WITH SECURITY_ENFORCED
                                       LIMIT 10000];

        for (Child__c ch : lstChildren) {
            Boolean foundMatchingContact = false;
            // If merging, skip any children with matching contacts already in household
            if (isMerge) {
                for (Contact ct : mapContactsInAccount.values()) {
                    if (ct.FirstName.equals(ch.First_Name__c) && ct.LastName.equals(ch.Last_Name__c)) {
                        foundMatchingContact = true;
                        // Populate fields with any new data.
                        // Conflicts go to the new values
                        if (String.isEmpty(ct.Program_Interests__c)) {
                            ct.Program_Interests__c = ch.Interests__c;
                        } else {
                            // Add any values not previously in contact program interests
                            ct.Program_Interests__c = getCombinedValuesForMSP(ch.Interests__c, ct.Program_Interests__c);
                        }
                        // Add or update birthdate
                        if (ct.Birthdate == null || (ch.Birthdate__c != null && ct.Birthdate != ch.Birthdate__c)) {
                            ct.Birthdate = ch.Birthdate__c;
                        }
                        // Add or update gender
                        if (String.isEmpty(ct.ssfl_Gender__c) || (!String.isEmpty(ch.Gender__c) && !ct.ssfl_Gender__c.equals(ch.Gender__c))) {
                            ct.ssfl_Gender__c = ch.Gender__c;
                        }
                        mapChildIdToConvertedContactId.put(ch.Id, ct.Id);
                        lstChildrenOfContacts.add(ch);
                        lstContactResults.add(ct);
                    }
                }
            }
            if (foundMatchingContact) {
                continue;
            }

            Contact ct = new Contact();
            ct.AccountId            = accountId;
            ct.FirstName            = ch.First_Name__c;
            ct.LastName             = ch.Last_Name__c;
            ct.Birthdate            = ch.Birthdate__c;
            ct.ssfl_Gender__c       = ch.Gender__c;
            ct.Program_Interests__c = ch.Interests__c;
            ct.Related_Lead_ID__c   = ch.Id;
            lstContactResults.add(ct);
            // Add child record to static variable to later update to converted
            lstChildrenOfContacts.add(ch);
        }

        return lstContactResults;
    }

    private static void markChildrenConverted(List<Child__c> lstChildrenOfContacts, 
                                                Map<Id,Id> mapChildIdToConvertedContactId) {

        for (Child__c ch : lstChildrenOfContacts) {
            ch.Converted_Contact__c = mapChildIdToConvertedContactId.get(ch.Id);
            ch.IsConverted__c       = true;
        }

        update lstChildrenOfContacts;

    }

    private static String getCombinedValuesForMSP(String strNewValues, String strOldValues) {
        String result = strOldValues;
        String[] lstOldValues = strOldValues.split(';');
        Set<String> setOldValues = new Set<String>();
        setOldValues.addAll(lstOldValues);
        String[] lstNewValues = strNewValues.split(';');
        if (!setOldValues.containsAll(lstNewValues)) {
            setOldValues.addAll(lstNewValues);
            result = String.join(new List<String>(setOldValues), ';');
        }
        return result;
    }
    
}