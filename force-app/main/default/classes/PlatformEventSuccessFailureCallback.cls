public with sharing class PlatformEventSuccessFailureCallback implements EventBus.EventPublishSuccessCallback, EventBus.EventPublishFailureCallback
{
    /*

    Order_Placed_Platform_Event__e pe = (Order_Placed_Platform_Event__e)Order_Placed_Platform_Event__e.SObjectType.newSObject(null, true);
    pe.Table_Number__c = '19';
    system.debug('Event UUID is ='+pe.EventUuid);
    Database.SaveResult result = EventBus.publish(pe, new PlatformEventSuccessFailureCallback());

    if(result.isSuccess())
    {
        system.debug('Event with UUID'+pe.EventUuid +' got successfully published!');
    }
    else
    {
        for(Database.Error err : result.getErrors())
        {
            System.debug('Event with UUID'+pe.EventUuid +' got failed to publish with error message:'+err.getMessage());
        }
    }
    */
   
   
   public void onSuccess(EventBus.SuccessResult result)
   {
       System.debug('Success');
       System.debug(result.getEventUuids());
   }

   public void onFailure(EventBus.FailureResult result)
   {
       System.debug('Failure');
       System.debug(result.getEventUuids());
   }

   @AuraEnabled
   public static void createPlatformEventRec()
   {
    try 
    {
        Order_Placed_Platform_Event__e pe = (Order_Placed_Platform_Event__e)Order_Placed_Platform_Event__e.SObjectType.newSObject(null, true);
        pe.Table_Number__c = UUID.randomUUID().toString();
        system.debug('Event UUID is ='+pe.EventUuid);
        Database.SaveResult result = EventBus.publish(pe, new PlatformEventSuccessFailureCallback());

        if(result.isSuccess())
        {
            system.debug('Event with UUID'+pe.EventUuid +' got successfully published!');
        }
        else
        {
            for(Database.Error err : result.getErrors())
            {
                System.debug('Event with UUID'+pe.EventUuid +' got failed to publish with error message:'+err.getMessage());
            }
        }    
    }
    catch (Exception e) 
    {
        throw new AuraHandledException(e.getMessage());
    }
   }
}