public class CreateContactsBatchClass implements Database.Batchable<sObject>, Queueable
{
    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        return Database.getQueryLocator('SELECT Id, Name, FirstName, LastName From COntact');
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope)
    {
        //integer q=1/0;
        List<contact> listOfContacts = new List<Contact>();
        for(COntact c: (List<Contact>)scope)
        {
            Contact cont = new contact(firstname=c.firstName+' batch', lastName=c.lastName+' batch');
            listOfContacts.add(cont);
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.Creatable, listOfContacts);
        if(decision.getRecords() != null && decision.getRecords().size() >0)
        {
            insert listOfContacts;
        }
        
    }   

    public void execute(QueueableContext qc)
    {
        List<Contact> listCOntacts = new List<Contact>();
        for(Contact c : [Select FirstName, LastName FROM COntact WITH Security_Enforced])
        {
            COntact cont = new COntact();
            cont.put('LastName', c.LastName+' queue');
            cont.put('FirstName', c.FirstName+' queue');
            listCOntacts.add(cont);
        }
        if(listCOntacts == null || listCOntacts.size() == 0)
        {
            return;
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.Creatable, listCOntacts);
        System.debug('decision.getRemovedFields.get(Contact)='+decision.getRemovedFields().get('Contact'));
        System.debug('decision.getRecords='+decision.getRecords());
        System.debug('decision.getRecords.size='+decision.getRecords().size());
        if(decision.getRemovedFields().get('Contact') == null && decision.getRecords() != null && decision.getRecords().size() == listCOntacts.size())
        {
            insert decision.getRecords();
        }
    }

    public void finish(Database.batchableContext bc)
    {
        System.debug('inside finish method');
        Database.executeBatch(new CreateContactsBatchClass());
    }
}