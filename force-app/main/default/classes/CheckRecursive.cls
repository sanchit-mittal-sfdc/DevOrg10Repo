/**
 * V. Imp class for checking recursion of trigger.
 * Lets us know if a trigger has already executed for a particular sObject record and action (e.g. before insert).
 * You might be thinking why cant we simply use a static boolean variable like :
 *  
 *  public static Boolean isAfterInserExecuted = false;
 *  
 *  But this is not accurate, especially in cases where more than one trigger can run in a single transaction.
 *  
 *  Here we use triggerRecursionCheckMap to store a unique execution id for each trigger context and we can then check for it and prevent
 */
public class CheckRecursive
{
    public static Map<String, Set<Id>> triggerRecursionCheckMap = new Map<String, Set<Id>>();

    public static Map<String, Set<String>> mapOperationTypeToAlreadyProcessedRecords;// = new Map<String, Set<String>>();

    public static Boolean CanThisRecordBeProcessed(String operationType, String recordId)
    {
        if(!mapOperationTypeToAlreadyProcessedRecords.containsKey(operationType))
        {
            mapOperationTypeToAlreadyProcessedRecords.put(operationType, new Set<String>{recordId});
            return true;
        }
        else
        {
            // check if record is present
            Boolean isRecordPresent = mapOperationTypeToAlreadyProcessedRecords.get(operationType).contains(recordId);

            if(isRecordPresent)
            {
                return false;
            }
            else
            {
                mapOperationTypeToAlreadyProcessedRecords.get(operationType).add(recordId);
                return true;
            }
        }
    }
}