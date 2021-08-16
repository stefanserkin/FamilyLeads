@isTest
public class FamilyLeadTriggerHandler_Test {

    @isTest
    static void insertFamilyLeadWithChildren() {

        Id familyLeadRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Family_Lead_Record_Type').getRecordTypeId();

        Lead ld                 = new Lead();
        ld.RecordTypeId         = familyLeadRTId;
        ld.FirstName            = 'Francisco';
        ld.LastName             = 'Lindor';
        ld.Company              = 'Individual';
        ld.Email                = 'francisco@mets.com';
        ld.Child1_First_Name__c = 'Francesca';
        ld.Child1_Last_Name__c  = 'Lindor';
        ld.Child1_Birthdate__c  = Date.today().addYears(-5);
        ld.Child2_First_Name__c = 'Frankie';
        ld.Child2_Last_Name__c  = 'Lindor';
        ld.Child2_Birthdate__c  = Date.today().addYears(-6);
        ld.Child3_First_Name__c = 'Cisco';
        ld.Child3_Last_Name__c  = 'Lindor';
        ld.Child3_Birthdate__c  = Date.today().addYears(-3);
        ld.Child4_First_Name__c = 'Frannie';
        ld.Child4_Last_Name__c  = 'Lindor';
        ld.Child4_Birthdate__c  = Date.today().addYears(-8);
        ld.Child5_First_Name__c = 'Cisca';
        ld.Child5_Last_Name__c  = 'Lindor';
        ld.Child5_Birthdate__c  = Date.today().addYears(-3);
        
        Test.startTest();
        Database.SaveResult sr = Database.insert(ld, false);
        Test.stopTest();

        Lead ldToVerify = [SELECT Id, Family_Lead__c, (SELECT Id FROM Children__r) FROM Lead WHERE Id = :ld.Id LIMIT 1];

        System.assert(sr.isSuccess(),
            'Insert was not successful'
        );
        System.assertEquals(true, ldToVerify.Family_Lead__c, 
            'Lead was not marked as family lead'
        );
        System.assertEquals(5, ldToVerify.Children__r.size(), 
            'Received wrong number of child records'
        );
    }

    @isTest
    static void insertFamilyLeadWithoutChildren() {

        Id familyLeadRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Family_Lead_Record_Type').getRecordTypeId();

        Lead ld                 = new Lead();
        ld.RecordTypeId         = familyLeadRTId;
        ld.FirstName            = 'Francisco';
        ld.LastName             = 'Lindor';
        ld.Company              = 'Individual';
        ld.Email                = 'francisco@mets.com';
        
        Test.startTest();
        Database.SaveResult sr = Database.insert(ld, false);
        Test.stopTest();

        Lead ldToVerify = [SELECT Id, Family_Lead__c, (SELECT Id FROM Children__r) FROM Lead WHERE Id = :ld.Id LIMIT 1];

        System.assert(sr.isSuccess(),
            'Insert was not successful'
        );
        System.assertEquals(false, ldToVerify.Family_Lead__c, 
            'Lead was not marked as family lead'
        );
        System.assertEquals(0, ldToVerify.Children__r.size(), 
            'Received wrong number of child records'
        );

    }

    @isTest
    static void insertIncompleteLead() {
        Lead badLead = new Lead();

        try {
            insert badLead;
        } catch (DmlException e) {
            System.assertEquals(e.getMessage(), e.getMessage());
        }
    }

    @isTest
    static void insertIncompleteChild() {
        Id familyLeadRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Family_Lead_Record_Type').getRecordTypeId();
        
        Lead ld                 = new Lead();
        ld.RecordTypeId         = familyLeadRTId;
        ld.FirstName            = 'Derek';
        ld.LastName             = 'Jeter';
        ld.Company              = 'Individual';
        ld.Email                = 'jeter@yanks.com';
        ld.Child1_First_Name__c = 'impossiblylongstringofchaactersthatexceedthe125allowedinanamesothisdefinitelycannotbesavedyesjusttrytosavesalesforceitwillnotworkbutiapplaudyoureffort';
        ld.Child1_Last_Name__c  = 'Jeter';
        ld.Child1_Birthdate__c  = Date.today().addYears(-5);

        Test.startTest();
        Database.SaveResult sr = Database.insert(ld, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Insert should have failed');
    }
    
}