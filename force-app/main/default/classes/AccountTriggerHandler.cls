public with sharing class AccountTriggerHandler
{
    public static void handleAfterUpdate(Map<Id, Account> newMap, Map<Id, Account> oldMap)
    {
        // ############################### CLone Account with Child COntacts If Type is Customer-Direct ############################
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
        if(Schema.SOBjectType.Contact.isCreateable() && clonedContacts != null && clonedContacts.size() > 0)
        {
            insert clonedContacts;
        }    
        // ############################### CLone Account with Child COntacts If Type is Customer-Direct ############################


        //################################ Update Billing Address if Lat and Long are updated with values #########################
        Set<Id> accountIdsToUpdate = new Set<Id>();
        for(Account a : newMap.values())
        {
            System.debug('a.Location__Latitude__s = '+a.Location__Latitude__s);
            System.debug('a.Location__Longitude__s = '+a.Location__Longitude__s);
            if( a.Location__Latitude__s != null && a.Location__Longitude__s != null && (a.Location__Latitude__s != oldMap.get(a.Id).Location__Latitude__s || a.Location__Longitude__s != oldMap.get(a.Id).Location__Longitude__s ) )
            {
                System.debug('Location is changed and not null so making callout');
                accountIdsToUpdate.add(a.Id);
            }
        }
        if(accountIdsToUpdate.size() > 0)
        {
            System.debug('Calling future method with accountIdsToUpdate='+accountIdsToUpdate);

            // Future method commented bcz whn i tried bulk 204 records only last 4 records were able to get updated.
            // bcz trigger ran 2 times first on 200 rec and then on 4 rec. FOr first run, it failed due to too many callout 101.
            // Hence I'm using batch class and setting the batch size 20 so that limits are not exceeded.
            //FutureMethodsClass.updateBillingAddress(accountIdsToUpdate);

            Database.executeBatch(new UpdateBillingAddressOnAccountsBatch(accountIdsToUpdate), 20);
        }
        //################################ Update Billing Address if Lat and Long are updated with values #########################
    }



    public static void handleAfterInsert(Map<Id, Account> newMap)
    {
        System.debug('Inside handleAfterInsert method');
        //################################ Update Billing Address if Lat and Long are updated with values #########################
        Set<Id> accountIdsToUpdate = new Set<Id>();
        for(Account a : newMap.values())
        {
            System.debug('a.Location__Latitude__s = '+a.Location__Latitude__s);
            System.debug('a.Location__Longitude__s = '+a.Location__Longitude__s);
            if( a.Location__Latitude__s != null && a.Location__Longitude__s != null)
            {
                system.debug('Location is present at time of inserting record and not null so making callout');
                accountIdsToUpdate.add(a.Id);
            }
        }
        if(accountIdsToUpdate.size() > 0)
        {
            System.debug('Calling future method with accountIdsToUpdate='+accountIdsToUpdate);
            // Future method commented bcz whn i tried bulk 204 records only last 4 records were able to get updated.
            // bcz trigger ran 2 times first on 200 rec and then on 4 rec. FOr first run, it failed due to too many callout 101.
            // Hence I'm using batch class and setting the batch size 20 so that limits are not exceeded.
            //FutureMethodsClass.updateBillingAddress(accountIdsToUpdate);

            Database.executeBatch(new UpdateBillingAddressOnAccountsBatch(accountIdsToUpdate), 20);
        }
        //################################ Update Billing Address if Lat and Long are updated with values #########################
    }

}