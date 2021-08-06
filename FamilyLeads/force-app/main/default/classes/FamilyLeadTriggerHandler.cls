public class FamilyLeadTriggerHandler {

    private static Id leadId;

    public static void createChildRecords(List<Lead> lstNewLeads) {

        List<Child__c> lstChildren = new List<Child__c>();

        List<Lead> lstFamilyLeads = new List<Lead>();
        lstFamilyLeads = getFamilyLeads(lstNewLeads);
        if (lstFamilyLeads.isEmpty()) {
            return;
        }

        for (Lead ld : lstFamilyLeads) {
            // Generate children records and add to list
            leadId = ld.Id;
            if (!String.isBlank(ld.Child1_First_Name__c)) {
                lstChildren.add(generateChildRecord(ld.Child1_First_Name__c, ld.Child1_Last_Name__c, ld.Child1_Age__c, ld.Child1_Interests__c));
            }
            if (!String.isBlank(ld.Child2_First_Name__c)) {
                lstChildren.add(generateChildRecord(ld.Child2_First_Name__c, ld.Child2_Last_Name__c, ld.Child2_Age__c, ld.Child2_Interests__c));
            }
            if (!String.isBlank(ld.Child3_First_Name__c)) {
                lstChildren.add(generateChildRecord(ld.Child3_First_Name__c, ld.Child3_Last_Name__c, ld.Child3_Age__c, ld.Child3_Interests__c));
            }
            if (!String.isBlank(ld.Child4_First_Name__c)) {
                lstChildren.add(generateChildRecord(ld.Child4_First_Name__c, ld.Child4_Last_Name__c, ld.Child4_Age__c, ld.Child4_Interests__c));
            }
            if (!String.isBlank(ld.Child5_First_Name__c)) {
                lstChildren.add(generateChildRecord(ld.Child5_First_Name__c, ld.Child5_Last_Name__c, ld.Child5_Age__c, ld.Child5_Interests__c));
            }
        }

        if (!lstChildren.isEmpty()) {
            try {
                insert lstChildren;
            } catch (DmlException e) {
                System.debug('An error occurred attempting to insert records: ' + e.getMessage());
            }
        }
        
    }

    private static List<Lead> getFamilyLeads(List<Lead> lstLeads) {
        List<Lead> lstFamilyLeads = new List<Lead>();
        for (Lead l : lstLeads) {
            if (l.Family_Lead__c) {
                lstFamilyLeads.add(l);
            }
        }
        return lstFamilyLeads;
    }

    private static Child__c generateChildRecord(String firstName, String lastName, 
                                                    Decimal age, String interests) {
        Child__c ch = new Child__c();
        ch.First_Name__c = firstName;
        ch.Last_Name__c  = lastName;
        ch.Age__c        = age;
        ch.Interests__c  = interests;
        ch.Parent__c     = leadId;

        return ch;
    }
    
}