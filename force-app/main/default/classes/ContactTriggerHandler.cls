public with sharing class ContactTriggerHandler {
    public static void onBeforeInsert(List<Contact> newContacts) {
        // Code here...
    }

    public static void onAfterInsert(List<Contact> newContacts) {
        List<Approval.ProcessSubmitRequest> submitRequests = new List<Approval.ProcessSubmitRequest>();
        Set<Id> accountIds = new Set<Id>();
        for (Contact newContact :  newContacts) {
            // Only submit approval for accounts doesn't have parent account and Active__c = false
            if (String.isBlank(newContact.AccountId)) continue;
            if (!newContact.Active__c) {
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setProcessDefinitionNameOrId('Contact_Approval');
                req.setSkipEntryCriteria(true);
                req.setObjectId(newContact.Id);
                submitRequests.add(req);
            } else {
                accountIds.add(newContact.AccountId);
            }
        }
        if (!submitRequests.isEmpty()) Approval.process(submitRequests);    // Submit for approval
        updateAccount(accountIds);  // Update Total_Contacts__c in Account
    }

    public static void onBeforeUpdate() {
        // Code here...
    }

    public static void onAfterUpdate(List<Contact> oldContacts, Map<Id, Contact> oldContactMap, List<Contact> newContacts, Map<Id, Contact> newContactMap) {
        // Get accountIds for update process
        Set<Id> accountIds = new Set<Id>();
        for (Id contactId : newContactMap.keySet()) {
            Contact oldContact = oldContactMap.get(contactId);
            Contact newContact = newContactMap.get(contactId);
            Boolean isContactUpdateByApprovalProcess = !oldContact.Active__c && newContact.Active__c && String.isNotBlank(newContact.AccountId);
            Boolean isActiveContactReparent = newContact.Active__c && String.isBlank(oldContact.AccountId) && String.isNotBlank(newContact.AccountId);
            if (isContactUpdateByApprovalProcess || isActiveContactReparent) {
                accountIds.add(newContact.AccountId);
            }
        }
        updateAccount(accountIds);  // Update Total_Contacts__c in Account
    }

    public static void onBeforeDelete(List<Contact> oldContacts) {
        // Code here...
    }

    public static void onAfterDelete(List<Contact> oldContacts) {
        // Get accountIds for update process
        Set<Id> accountIds = new Set<Id>();
        for (Contact oldContact : oldContacts) {
            if (oldContact.Active__c && String.isNotBlank(oldContact.AccountId)) {
                accountIds.add(oldContact.AccountId);
            }
        }
        updateAccount(accountIds);  // Update Total_Contacts__c in Account
    }

    private static void updateAccount(Set<Id> accountIds) {
        try {
            List<Account> accountsToUpdate = new List<Account>();
            for (List<Account> accs : [SELECT Id, Total_Contacts__c, (SELECT Id, Name FROM Contacts WHERE Active__c = TRUE)
                                       FROM Account
                                       WHERE Id IN :accountIds
                                       WITH SECURITY_ENFORCED]) {
                for (Account acc : accs) {
                    acc.Total_Contacts__c = acc.Contacts.size();
                    accountsToUpdate.add(acc);
                }                           
            }
            if (!accountsToUpdate.isEmpty()) {
                SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.UPDATABLE, accountsToUpdate);
                update securityDecision.getRecords();
            }

        } catch (Exception ex) {
            System.debug('@@@ Exception found: ' + ex.getMessage());
        }     
    }
}