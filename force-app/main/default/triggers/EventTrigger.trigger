trigger EventTrigger on Event (before insert, after insert, before update, after update, before delete, after delete, after undelete)
{
    System.debug('EventTrigger called with operationType='+Trigger.operationType);
    System.debug('System.isFuture() is '+System.isFuture());

    if(!System.isFuture())
    {
        switch on Trigger.operationType
        {
            when BEFORE_INSERT
            {
                EventTriggerHandler.handleBeforeInsert(Trigger.new);
            }
            when AFTER_INSERT
            {
                EventTriggerHandler.handleAfterInsert(Trigger.newMap);
            }
            when BEFORE_UPDATE
            {
                /*
                if(!EventTriggerHandler.hasBeforeUpdateAlreadyExecuted)
                {
                    EventTriggerHandler.hasBeforeUpdateAlreadyExecuted = true;
                    EventTriggerHandler.handleBeforeUpdate(Trigger.oldMap, Trigger.newMap);
                }
                */
                EventTriggerHandler.handleBeforeUpdate(Trigger.oldMap, Trigger.newMap);
            }
            when AFTER_UPDATE
            {
                /*
                if(!EventTriggerHandler.hasAfterUpdateAlreadyExecuted)
                {
                    EventTriggerHandler.hasAfterUpdateAlreadyExecuted = true;
                    EventTriggerHandler.handleAfterUpdate(Trigger.oldMap, Trigger.newMap);
                }
                */
                EventTriggerHandler.handleAfterUpdate(Trigger.oldMap, Trigger.newMap);
            }
        }
    }
}