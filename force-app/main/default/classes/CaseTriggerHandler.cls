public class CaseTriggerHandler
{
    public static void handleAfterUpdate(Map<Id, Case> newMap, Map<Id, Case> oldMap)
    {        
        Set<Id> accountIdsToEvaluate = new Set<Id>();
        List<Account> accountsToUpdate = new List<Account>();

        for( Case c : newMap.values() )
        {
            if(c.accountId != null && newMap.get(c.Id).Status != oldMap.get(c.Id).Status && newMap.get(c.Id).isClosed && newMap.get(c.Id).Status.equalsIgnoreCase('Closed') )
            {
                accountIdsToEvaluate.add(c.accountId);

            }    
        }

        if(accountIdsToEvaluate == null || accountIdsToEvaluate.size()==0)
            return;

		
		Map<Id, Integer> mapAccountIdToTotalDays = new  Map<Id, Integer>();
		Map<Id, Integer> mapAccountIdToTotalCases = new  Map<Id, Integer>();
		
		for(Case c : [SELECT Id, AccountId, CreatedDate, ClosedDate FROM Case WHERE AccountId IN : accountIdsToEvaluate] )
		{
			Integer totalResolutionDays = Date.valueOf(c.createdDate).daysBetween( Date.valueOf(c.closedDate) );
			
			if( !mapAccountIdToTotalCases.containsKey(c.AccountId))
			{
				mapAccountIdToTotalCases.put(c.accountId, 1);
				mapAccountIdToTotalDays.put(c.accountId, totalResolutionDays);
				
			}
			else
			{
				Integer newCount = mapAccountIdToTotalCases.get(c.accountId) + 1;
				mapAccountIdToTotalCases.put(c.accountId, newCount);
				
				mapAccountIdToTotalDays.put(c.accountId, totalResolutionDays + mapAccountIdToTotalDays.get(c.accountId));
			}
				
		}
		
		for(Id accId : mapAccountIdToTotalCases.keySet())
		{
			accountsToUpdate.add( new Account( Id = accId, Avg_Resolution_Days__c = String.valueOf( (Decimal)mapAccountIdToTotalDays.get(accId)/mapAccountIdToTotalCases.get(accId) ) ) );
		}
		update accountsToUpdate;

    } 
}