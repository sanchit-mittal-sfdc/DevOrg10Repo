public class ContactTriggerHandler
{
    public static void handleBeforeInsert( List<Contact> newContacts )
    {  
        Set<Id> setAccountIds = new Set<Id>();
        Map<Id,Account> mapAccountIdToAccount;

        for(Contact c : newContacts)
        {
            if(c.AccountId != null)
            {
                setAccountIds.add(c.AccountId);
            }
        }

        // IMP: this is imp to avoid one more for loop
       mapAccountIdToAccount = new Map<Id, Account>([SELECT Id,City__c FROM Account WHERE Id IN :setAccountIds]);

       for(Contact c: newContacts)
       {
           if(c.AccountId != null && mapAccountIdToAccount.containsKey(c.AccountId) )
           {
               c.City__c = mapAccountIdToAccount.get(c.AccountId).City__c;
           }
       }

    }

    public static void handleAfterInsert( Map<Id, Contact> newMap )
    {
        FutureMethodsClass.sampleFutureMethod(newMap.keyset());

        Set<Id> accountIdsAffected = new Set<Id>();
        for(Contact c : newMap.values())
        {
            if(c.AccountId != null)
            {
                accountIdsAffected.add(c.AccountId);
            }
        }
        if(accountIdsAffected.size()>0)
        {
            updateChildCOntactsCountOnAccount(accountIdsAffected);
        }
    }

    public static void handleAfterUpdate( Map<Id, Contact> newMap, Map<Id, COntact> oldMap )
    {
        if( !CheckRecursive.triggerRecursionCheckMap.containsKey('ContactTrigger_BeforeUpdate'))
        {
            CheckRecursive.triggerRecursionCheckMap.put('ContactTrigger_BeforeUpdate', new Set<Id>());
        }

        Set<Id> accountIdsAffected = new Set<Id>();
        for(Contact c : newMap.values())
        {
            if( !CheckRecursive.triggerRecursionCheckMap.get('ContactTrigger_BeforeUpdate').contains(c.Id) )
            {
                if(c.AccountId != oldMap.get(c.Id).AccountId)
                {
                    accountIdsAffected.add(c.AccountId);
                    accountIdsAffected.add(oldMap.get(c.Id).AccountId);
                }
            }
            else{
                CheckRecursive.triggerRecursionCheckMap.get('ContactTrigger_BeforeUpdate').add(c.Id);
            }
            
        }
        if(accountIdsAffected.size()>0)
        {
            updateChildCOntactsCountOnAccount(accountIdsAffected);
        }
    }

    public static void handleAfterDelete( Map<Id, Contact> oldMap )
    {
        Set<Id> accountIdsAffected = new Set<Id>();
        for(Contact c : oldMap.values())
        {
            if(c.AccountId != null)
            {
                accountIdsAffected.add(c.AccountId);
            }
        }
        if(accountIdsAffected.size()>0)
        {
            updateChildCOntactsCountOnAccount(accountIdsAffected);
        }
    }

    public static void handleAfterUnDelete( Map<Id, Contact> newMap )
    {
        Set<Id> accountIdsAffected = new Set<Id>();
        for(Contact c : newMap.values())
        {
            if(c.AccountId != null)
            {
                accountIdsAffected.add(c.AccountId);
            }
        }
        if(accountIdsAffected.size()>0)
        {
            updateChildCOntactsCountOnAccount(accountIdsAffected);
        }
    }

    /*****************************************************************************************
    V. IMP:  This is also perfect approach 1 and we can also use group by and aggregate function to perform count
    which is exactly what I have done in the Approach 2
    ****************************************************************************************
    static void updateChildCOntactsCountOnAccount(Set<Id> accountIdsAffected)
    {
        Map<Id, Integer> mapAccIdToChildContactsCount = new Map<Id, Integer>();
        for(Contact c : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accountIdsAffected WITH SECURITY_ENFORCED])
        {
            if(!mapAccIdToChildContactsCount.containsKey(c.AccountId))
            {
                mapAccIdToChildContactsCount.put(c.AccountId, 1);
            }
            else
            {
                Integer existingCount = mapAccIdToChildContactsCount.get(c.AccountId);
                mapAccIdToChildContactsCount.put(c.AccountId, existingCount+1);
            }
        }

        if(mapAccIdToChildContactsCount.size() > 0)
        {
            List<Account> accountsToUpdate = new List<Account>();
            for(Id accId : mapAccIdToChildContactsCount.keySet())
            {
                accountsToUpdate.add( new Account(Id = accId, Total_Child_Contacts__c = mapAccIdToChildContactsCount.get(accId)) );
            }

            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, accountsToUpdate);

            if(decision.getRemovedFields().get('Account') == null && decision.getRecords() != null && decision.getRecords().size() == accountsToUpdate.size())
            {
                update decision.getRecords();
            }
        }
    }
    */

    /*******************************************************************************************
    APPROACH 2 using group by and count()
    *************************************************************************************/
    static void updateChildCOntactsCountOnAccount(Set<Id> accountIdsAffected)
    {
        Map<Id, Integer> mapAccIdToChildContactsCount = new Map<Id, Integer>();
        for(AggregateResult ar : [SELECT Count(Id) cnt, AccountId FROM Contact WHERE AccountId IN :accountIdsAffected GROUP BY AccountId])
        {
            
            mapAccIdToChildContactsCount.put( String.valueOf(ar.get('AccountId')), Integer.valueOf(ar.get('cnt')) );
         
        }

        if(mapAccIdToChildContactsCount.size() > 0)
        {
            List<Account> accountsToUpdate = new List<Account>();
            for(Id accId : mapAccIdToChildContactsCount.keySet())
            {
                accountsToUpdate.add( new Account(Id = accId, Total_Child_Contacts__c = mapAccIdToChildContactsCount.get(accId)) );
            }

            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, accountsToUpdate);

            if(decision.getRemovedFields().get('Account') == null && decision.getRecords() != null && decision.getRecords().size() == accountsToUpdate.size())
            {
                update decision.getRecords();
            }
        }
    }
}