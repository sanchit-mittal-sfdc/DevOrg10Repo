/*
######################################################################################################
https://www.pantherschools.com/create-update-custom-metadata-using-apex/    
Developer console:

    Map<String, Object> maptest = new Map<String, Object>();
    maptest.put('AccessToken__c', 'test token new');
    maptest.put('Instance_URL__c', 'Admin');
    maptest.put('Refresh_Token__c', 'refresh');
    CreateUpdateMetadataUtils.createUpdateMetadata('SFDC_Config__mdt.TEST_sm','TEST sm',maptest); //  here "__mdt" is oprtional, even "SFDC_Config" will work
 



    ######################################## Without requirng this class:

    Metadata.CustomMetadata cmd =new Metadata.CustomMetadata();
    cmd.fullName = 'SFDC_Config__mdt.Dablu_Bhaiya';
    cmd.Label = 'Dablu Bhaiya';

    Metadata.CustomMetadataValue cmdCustomField = new Metadata.CustomMetadataValue();
    cmdCustomField.field='AccessToken__c';
    cmdCustomField.value='paplu';
    cmd.values.add(cmdCustomField);

    Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
    mdContainer.addMetadata(cmd);

    Metadata.Operations.enqueueDeployment(mdCOntainer, null); // we can pass null well

    ######################################################################################################
*/

public class CreateUpdateMetadataUtils implements Metadata.DeployCallback {
    
    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        if (result.status == Metadata.DeployStatus.Succeeded) {
            System.debug(' success : '+ result);
        } else {
            System.debug(' fail : '+ result);
        }
    }
    
    public static void createUpdateMetadata(String fullName, String label, Map<String, Object> fieldWithValuesMap){
        System.debug('createUpdateMetadata is called with fieldWithValuesMap = '+fieldWithValuesMap);
        Metadata.CustomMetadata customMetadata =  new Metadata.CustomMetadata();
        customMetadata.fullName = fullName;
        customMetadata.label = label;
        
        for(String key : fieldWithValuesMap.keySet()){
            Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
            customField.field = key;
            customField.value = fieldWithValuesMap.get(key); 
            customMetadata.values.add(customField);
        }
        
        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customMetadata);
        CreateUpdateMetadataUtils callback = new CreateUpdateMetadataUtils();

        try {
            Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, callback);
            System.debug('Metadata deployment time='+system.now() + ' and job ID = '+jobId);
        } catch (Exception e) {
            System.debug('Deployment failed to enqueue: ' + e.getMessage());
        }
        
    }
}