/* BULK Testing script
List<Account> lst = new List<Account>();
for(integer i=1; i<205;i++)
{
    Account a =new Account();
    a.Name = 'TestBulk'+i;
    if(Math.mod(i,2)==0)
    {
        a.Location__Latitude__s = 28.628549239709997;
    	a.Location__Longitude__s=77.35964760786091;
    }
    else
    {
     	a.Location__Latitude__s = 28.69906264694065;
    	a.Location__Longitude__s=77.13633109437207;   
    }
    lst.add(a);
}
insert lst;    
delete [SELECT Id,name,Location__Latitude__s, Location__Longitude__s, billingcity ,billingstate, billingcountry, billingpostalcode FROM Account where name like 'testbulk%'];
*/

public inherited sharing class UpdateBillingAddressOnAccountsBatch implements Database.Batchable<SObject>, Database.AllowsCallouts
{
    Set<Id> accountIdsToUpdate;

    public UpdateBillingAddressOnAccountsBatch(Set<Id> accountIdsToUpdate) 
    {
        this.accountIdsToUpdate = accountIdsToUpdate;
    }

    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        // If there is No update permission for current user on Account object then no need to proceed further.
        // Also, I could have checked for other FLS permission here itself using 
        // schema.sObjectType.Account.fields.Location__Latitude__s.isUpdatable() but I'll be using other method in code ahead
        if( !(schema.sObjectType.Account.isUpdateable() && schema.SObjectType.Account.fields.BillingCity.isUpdateable()) )
        {
          return null;  
        }
        return Database.getQueryLocator('SELECT Id,Location__Latitude__s, Location__Longitude__s, BillingCity, BillingState, BillingPostalCOde, BillingCountry  FROM Account WHERE Id IN :accountIdsToUpdate');
    }

    public void execute(Database.BatchableContext bc, List<Account> scope)
    {
        List<Account> listOfAccountsToUpdate = new List<Account>();
        for( Account acc : scope)
        {
            Account accPopulatedWithDetails = doCalloutToFetchLocation(acc);
            if( accPopulatedWithDetails != null )
            {
                listOfAccountsToUpdate.add(accPopulatedWithDetails);
            }
        }

        if( listOfAccountsToUpdate.size() > 0 )
        {
            update listOfAccountsToUpdate;
        }
    }


    public void finish(Database.BatchableContext bc)
    {

    }

    public static Account doCalloutToFetchLocation(Account acc)
    {
        if (acc.Location__Latitude__s == null || acc.Location__Longitude__s == null) {
            System.debug('Account-'+acc.Name +' does not have latitude or longitude values');
            return null;
        }

        String endPointUrl = 'https://api.opencagedata.com/geocode/v1/json';
        Decimal latValue = acc.Location__Latitude__s;
        Decimal lonValue = acc.Location__Longitude__s;
        String apiKey = '1423aea6b9bb41e180db76fa9e0ab0ac';
        String finalEndPointUrl = endPointUrl + '?q=' + latValue + ',' + lonValue +'&key=' + apiKey;
        System.debug('finalEndPointUrl = '+finalEndPointUrl);

        HttpRequest req = new HttpRequest();
        req.setEndPoint(finalEndPointUrl);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');

        Http h = new Http();
        HttpResponse res;
        try
        {
            res = h.send(req);
        } 
        catch (Exception e) {
           system.debug('callout failed-'+e.getMessage()); 
           return null;
        }
        
        system.debug('STatus code-'+res.getStatusCode()); 
        if(res.getStatusCode() != 200)
        {
            
            return null;
        }

        ResponseWrapper resultWrapper = (ResponseWrapper)JSON.deserialize(res.getBody(), ResponseWrapper.class);
        system.debug(resultWrapper);

        if( resultWrapper != null && resultWrapper.results != null && resultWrapper.results.size() > 0 && resultWrapper.results[0].components != null )
        {
            acc.BillingCity = resultWrapper.results[0].components.suburb != null? (resultWrapper.results[0].components.suburb + ' '):'';
            acc.BillingCity += resultWrapper.results[0].components.city != null ? resultWrapper.results[0].components.city :'';
        }
        else {
            return null;
        }

        //acc.BillingState = (resultWrapper.results[0].components.state != null ? resultWrapper.results[0].components.state+' ' : '')  + resultWrapper.results[0].components.county != null ?resultWrapper.results[0].components.county :'';
        acc.BillingState = resultWrapper.results[0].components.state;
        acc.BillingCountry = resultWrapper?.results[0]?.components?.country;
        acc.BillingPostalCOde = resultWrapper?.results[0]?.components?.postcode;

        return acc;
    }

    public class ResponseWrapper
    {
        List<SubWrapper> results;     
    }
    public class SubWrapper
    {
        public ComponentWrapper components;
    }

    public class ComponentWrapper
    {
        public String country;
        public String state;
        public String postcode;
        public String suburb;
        public String state_district;
        public String city;
        public String county;
        
    }
}