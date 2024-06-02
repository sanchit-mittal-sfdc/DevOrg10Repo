public without sharing class AccountTriggerHandler
{
    public static void handleAfterUpdate(Map<Id, Account> newMap, Map<Id, Account> oldMap)
    {
        system.debug('CI/CD pipeline test1111 24 apr');
        system.debug('sanchit ch  cfb gunjannnnnn');
        Set<Id> accountIdsToClone = new Set<Id>();

        for(Account a : newMap.values())
        {
            if(a.Type != null && a.Type.equalsIgnoreCase('Customer - Direct') && a.Type != oldMap.get(a.Id).Type)
            {
                accountIdsToClone.add(a.Id);
            }
        }

        List<Account> clonedAccountsToInsert = new List<Account>();
        Map<String, List<Contact> > mapAccountNameToChildContacts = new Map<String, List<Contact> >();

        for(Account a : [SELECT Id, Name, (SELECT Id, FirstName, LastName, Email FROM Contacts) FROM Account WHERE Id IN :accountIdsToClone WITH SECURITY_ENFORCED])
        {
            clonedAccountsToInsert.add(new Account(Name = a.Name + '-cloned') );
            mapAccountNameToChildContacts.put(a.name, a.Contacts);
        }

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, clonedAccountsToInsert);

        if(decision.getRemovedFields().get('Account') == null && decision.getRecords() != null)
        {
            insert decision.getRecords();
        }

        List<Contact> clonedContacts = new List<Contact>();
        for(Account a : (List<Account>)decision.getRecords() )
        {   
            for(Contact c : mapAccountNameToChildContacts.get( a.name.removeEnd('-cloned') ) )
            {
                Contact con = c.clone(false, true, false, false);
                con.AccountId = a.Id;
                clonedContacts.add(con);
            }
        }
        insert clonedContacts;

    }
}