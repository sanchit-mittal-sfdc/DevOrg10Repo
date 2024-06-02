trigger CaseTrigger on Case (after update, before update)
{
    switch on trigger.operationType
    {
        when AFTER_UPDATE{
         CaseTriggerHandler.handleAfterUpdate(trigger.newMap, trigger.oldMap);   
        }
    }
}