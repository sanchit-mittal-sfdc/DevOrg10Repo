trigger AccountTrigger on Account (after update) 
{
    switch on trigger.operationType{
    
        when AFTER_UPDATE{
            AccountTriggerHandler.handleAfterUpdate(trigger.newMap, trigger.oldMap);
        }
    }
}