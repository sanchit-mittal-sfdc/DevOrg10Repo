import { LightningElement } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import Toast from 'lightning/toast';
import createPlatformEventRec from '@salesforce/apex/PlatformEventSuccessFailureCallback.createPlatformEventRec';

export default class KitchenOrderTrackerLwc extends LightningElement {

    /*
    Order_Placed_Platform_Event__e pe = (Order_Placed_Platform_Event__e)Order_Placed_Platform_Event__e.SObjectType.newSObject(null, true);
    pe.Table_Number__c = '119';
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
    channelName = '/event/Order_Placed_Platform_Event__e';
    subscription;
    info;

    connectedCallback(){
        console.log(`connectedCallback is called`);
        this.registerErrorListener();
        this.doSubscribeToOrderPlacedPlatformEvent();
    }

    doSubscribeToOrderPlacedPlatformEvent()
    {
        // Callback invoked whenever a new event message is received
        const messageCallback =  (response) => {
            debugger;
            console.log('New message received: ', JSON.stringify(response));
            this.info = 'Table_Number__c field value: '+ response.data.payload.Table_Number__c;
            Toast.show({
                label:"Order Received!",
                message:`Order received for Table ${response.data.payload.Table_Number__c}`,
                mode:"dismissible",
                variant:"success"
            }, this);
        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        this.subscription = subscribe(this.channelName, -2, messageCallback);
       
        console.log(`this.subscription = ${this.subscription}`);
    }

    disconnectedCallback(){
        console.log('disconnectedCallback called in kitchenOrder');
        //this.doUnsubscribe();
    }

    doUnsubscribe(){
        debugger;
        if(this.subscription)
        {
            unsubscribe(this.subscription, (response) => {
                console.log(`unsubscribe response= ${JSON.stringify(response)}`);
                alert('successfully unsibscribed');
            });
        }
    }


    registerErrorListener(){
        onError(error => {
            console.error(error);
        });
    }


    async handleButtonClick()
    {
        await createPlatformEventRec({});
    }
}