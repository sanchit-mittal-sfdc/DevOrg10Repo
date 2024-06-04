trigger AccountTrigger on Account (after insert, after update) 
{
    System.debug('AccountTrigger called');
    switch on trigger.operationType{
    
        when AFTER_UPDATE{
            System.debug('AFTER_UPDATE');
            AccountTriggerHandler.handleAfterUpdate(trigger.newMap, trigger.oldMap);
        }

        when after_insert{
            System.debug('after_insert');
            AccountTriggerHandler.handleAfterInsert(trigger.newMap);
        }
    }
}