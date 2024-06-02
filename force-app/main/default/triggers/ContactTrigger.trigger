trigger ContactTrigger on Contact (before insert, after insert, before update, after update, before delete, after delete, after undelete)
{
    switch on trigger.operationType
    {
        when BEFORE_INSERT {
            ContactTriggerHandler.handleBeforeInsert(trigger.new);
        }
        
        when AFTER_INSERT{
            ContactTriggerHandler.handleAfterInsert(trigger.newMap);
        }
        
        when AFTER_UPDATE{
            ContactTriggerHandler.handleAfterUpdate(trigger.newMap, trigger.oldMap);
        }
        
        when AFTER_DELETE{
            ContactTriggerHandler.handleAfterDelete(trigger.oldMap);
        }
        
        when AFTER_UNDELETE{
            ContactTriggerHandler.handleAfterUndelete(trigger.newMap);
        }
    }
}