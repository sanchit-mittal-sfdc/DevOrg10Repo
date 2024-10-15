import { LightningElement } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import Toast from 'lightning/toast';

export default class ChangeDataCaptureDemoLwc extends LightningElement {

    subscription;
    channelName = '/data/ContactChangeEvent'; // for custom objects its like Restaurant__ChangeEvent

    connectedCallback(){

        this.registerErrorListener();
        this.subscribeContactChangeEvent();
    }

    subscribeContactChangeEvent()
    {
        const messageCallback = (response) => {
            console.log(`There's a change in a contact record. Details: ${JSON.stringify(response)}`);
            Toast.show({
                label:"Change in contact record captured!",
                message:`Contact id: ${response.data.payload.ChangeEventHeader.recordIds[0]} and changed fields are : ${response.data.payload.ChangeEventHeader.changedFields.join(',')}`,
                variant:"success",
                mode:`sticky`
            },this);
        };

        this.subscription = subscribe(this.channelName, -2, messageCallback);
    }


    registerErrorListener()
    {
        onError(error => {
            console.error(error);
        });
    }

    disconnectedCallback()
    {
        this.doUnsubscribe();
    }

    doUnsubscribe()
    {
        unsubscribe(this.subscription, (response) => {
            console.log('unsubscribe response='+JSON.stringify(response));
        });
    }
}