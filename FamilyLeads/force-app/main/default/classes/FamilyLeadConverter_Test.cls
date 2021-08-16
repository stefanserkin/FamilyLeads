@isTest
public class FamilyLeadConverter_Test {

    @TestSetup
    static void setupData(){

        Account accForMerge = new Account(Name='Ordonez Household');
        Id hhRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('HH_Account').getRecordTypeId();
        accForMerge.RecordTypeId = hhRTId;
        insert accForMerge;

        List<Contact> lstContacts = new List<Contact>();
        Contact ctForMerge = new Contact(FirstName='Rey',LastName='Ordonez',Email='rey@mets.com',AccountId=accForMerge.Id);
        lstContacts.add(ctForMerge);
        Contact childCtForMerge = new Contact(FirstName='Lilrey0',LastName='Ordonez',AccountId=accForMerge.Id);
        lstContacts.add(childCtForMerge);
        insert lstContacts;

        Lead ld = new Lead(FirstName='Rey',LastName='Ordonez',Email='rey@mets.com',Company='Individual');
        Id familyLeadRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Family_Lead_Record_Type').getRecordTypeId();
        ld.RecordTypeId = familyLeadRTId;
        insert ld;

        List<Child__c> lstChildren = new List<Child__c>();
        for (Integer i = 0; i < 5; i++) {
            Child__c ch = new Child__c();
            ch.First_Name__c = 'Lilrey'+String.valueOf(i);
            ch.Last_Name__c  = 'Ordonez';
            ch.Birthdate__c  = Date.today().addYears(-i+1);
            ch.Parent__c     = ld.Id;
            lstChildren.add(ch);
        }
        insert lstChildren;
        
    }
    
    @isTest
    static void convertNewFamilyLead() {

        Lead lead = new Lead();
        List<Id> childrenIds = new List<Id>();
        Boolean convertChildren = true;
        
        lead = [SELECT Id, FirstName, LastName, Email, RecordTypeId, Company,
                       (SELECT Id, First_Name__c, Last_Name__c, Birthdate__c, Parent__c 
                          FROM Children__r)
                  FROM Lead
                 LIMIT 1];
        for (Child__c ch : lead.Children__r) {
            childrenIds.add(ch.Id);
        }

        Test.startTest();

        List<FamilyLeadConverter.ConvertResult> resultList;

        FamilyLeadConverter.ConvertRequest request;
        request = new FamilyLeadConverter.ConvertRequest();
        request.childrenIds = childrenIds;
        request.convertChildren = convertChildren;
        request.lead = lead;

        resultList = FamilyLeadConverter.convertLead(
            new List<FamilyLeadConverter.ConvertRequest>{ request }
        );

        Test.stopTest();

        System.assertEquals(true, resultList.size() > 0, 
            'Expected to receive conversion results'
        );

        Id accId = resultList.get(0).accountIdResult;

        Account accWithCts = [SELECT Id, Name,
                                     (SELECT Id FROM Contacts)
                                FROM Account
                               WHERE Id = :accId
                               LIMIT 1];

        // Add one for parent
        Integer numExpectedCts = lead.Children__r.size() + 1;
        Integer numContacts    = accWithCts.Contacts.size();
        
        System.assertEquals(numExpectedCts, numContacts, 
            'Wrong number of contacts in account'
        );


    }

    @isTest
    static void convertNewFamilyLeadOnlyParent() {

        Lead lead = new Lead();
        List<Id> childrenIds = new List<Id>();
        Boolean convertChildren = false;
        
        lead = [SELECT Id, FirstName, LastName, Email, RecordTypeId, Company,
                       (SELECT Id, First_Name__c, Last_Name__c, Birthdate__c, Parent__c 
                          FROM Children__r)
                  FROM Lead
                 LIMIT 1];

        Test.startTest();

        List<FamilyLeadConverter.ConvertResult> resultList;

        FamilyLeadConverter.ConvertRequest request;
        request = new FamilyLeadConverter.ConvertRequest();
        request.childrenIds = childrenIds;
        request.convertChildren = convertChildren;
        request.lead = lead;

        resultList = FamilyLeadConverter.convertLead(
            new List<FamilyLeadConverter.ConvertRequest>{ request }
        );

        Test.stopTest();

        System.assertEquals(true, resultList.size() > 0, 
            'Expected to receive conversion results'
        );

        Id accId = resultList.get(0).accountIdResult;

        Account accWithCts = [SELECT Id, Name,
                                     (SELECT Id FROM Contacts)
                                FROM Account
                               WHERE Id = :accId
                               LIMIT 1];

        // Only parent was converted
        Integer numExpectedCts = 1;
        Integer numContacts    = accWithCts.Contacts.size();
        
        System.assertEquals(numExpectedCts, numContacts, 
            'Wrong number of contacts in account'
        );


    }

    @isTest
    static void mergeFamilyLead() {

        List<Id> childrenIds = new List<Id>();
        Boolean convertChildren = true;
        Id matchingContactId;
        Id matchingAccountId;
        
        // Get Program Interest available values
        Schema.DescribeSObjectResult conObj = Contact.sObjectType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = conObj.fields.getmap();
        List<Schema.Picklistentry> mspValues = fieldMap.get('Program_Interests__c').getDescribe().getpicklistValues();
        List<String> programValues = new List<String>();
        for (Schema.Picklistentry mspValue : mspValues) {
            programValues.add(mspValue.getValue());
        }
        
        Lead lead = [SELECT Id, FirstName, LastName, Email, RecordTypeId, Company,
                            (SELECT Id, First_Name__c, Last_Name__c, Birthdate__c, Parent__c, Interests__c, Gender__c
                               FROM Children__r)
                       FROM Lead
                      LIMIT 1];
        
        Child__c lilrey0 = new Child__c();
        for (Child__c ch : lead.Children__r) {
            childrenIds.add(ch.Id);
            if (ch.First_Name__c.equalsIgnoreCase('Lilrey0') ||
               	ch.First_Name__c.equalsIgnoreCase('Lilrey1')) {
                lilrey0 = ch;
                // Update child interest with available value
                lilrey0.Interests__c = programValues.get(1);
                System.debug('lilrey0 program values updated to: ' + lilrey0.Interests__c);
            }
        }
        update lilrey0;
		
        Account accForMerge = [SELECT Id, Name, (SELECT Id,FirstName,LastName,Birthdate,ssfl_Gender__c,Email,Program_Interests__c FROM Contacts) FROM Account LIMIT 1];

        // Add second contact to account to test added program interests
        Contact newCt = new Contact(FirstName='Lilrey1',LastName='Ordonez',AccountId=accForMerge.Id);
        newCt.Program_Interests__c = programValues.get(0);
        insert newCt;

        Test.startTest();
        List<FamilyLeadConverter.ConvertResult> resultList;

        FamilyLeadConverter.ConvertRequest request;
        request = new FamilyLeadConverter.ConvertRequest();
        request.childrenIds = childrenIds;
        request.convertChildren = convertChildren;
        request.lead = lead;
        request.matchingAccountId = accForMerge.Id;
        request.matchingContactId = accForMerge.Contacts.get(0).Id;

        resultList = FamilyLeadConverter.convertLead(
            new List<FamilyLeadConverter.ConvertRequest>{ request }
        );

        Test.stopTest();

        System.assertEquals(true, resultList.size() > 0, 
            'Expected to receive conversion results'
        );

        Id accId = resultList.get(0).accountIdResult;

        Account accWithCts = [SELECT Id, Name,
                                     (SELECT Id FROM Contacts)
                                FROM Account
                               WHERE Id = :accId
                               LIMIT 1];

        // Add one for parent
        Integer numExpectedCts = lead.Children__r.size() + 1;
        Integer numContacts    = accWithCts.Contacts.size();
        
        System.assertEquals(numExpectedCts, numContacts, 
            'Wrong number of contacts in account'
        );

    }

}