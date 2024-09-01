import { LightningElement } from 'lwc';
import getDeviceCodeAndVerificationLink from '@salesforce/apex/DeviceFlowLwcController.getDeviceCodeAndVerificationLink';
import checkDeviceAuthenticationStatus from '@salesforce/apex/DeviceFlowLwcController.checkDeviceAuthenticationStatus';
import Toast from 'lightning/toast';

export default class DeviceFlowLwc extends LightningElement {

    loginGuidelinetext;
    verificationUrl;
    deviceCode;
    userCode;
    pollingInterval;
    intervalId;
    pollingStartTime;
    pollingStarted = false;
    maxPollingDurationInMiliSec = 5 * 60 * 1000; // 5 mins
    

    async signInHandler(event){

        try
        {
            const response = await getDeviceCodeAndVerificationLink({});
            debugger;

            if(response && response.isSuccess )
            {
                console.log(JSON.stringify(response));

                this.loginGuidelinetext = `Please open the following link in your browser:`;
                this.pollingInterval = response.interval * 1000; // in ms
                this.deviceCode = response.device_code;
                this.userCode = response.user_code;
                this.verificationUrl = response.verification_uri;
                // Start polling to check if the authentication is successful i.e. if the user has clicked the verification URL and entered the code. Check for max 5 mins
                this.pollingStartTime = new Date().getTime();
                console.log(`this.pollingStartTime = ${this.pollingStartTime}`);
                this.startPolling();

            }
            else
            {
                Toast.show({
                                label:'Error',
                                message:`Error occured: ${response?.errorMessage}`,
                                variant: 'error',
                                mode: 'sticky'
                        },this);
            }
        }
        catch(error)
        {
            console.log(`Some error occured: ${error.body.message}`);

            Toast.show({
                label:'Error',
                message:`Some error occured: ${error.body.message}`,
                variant: 'error',
                mode: 'sticky'
            }, this);
        }
        

    }


    startPolling()
    {
        this.pollingStarted = true;
        this.intervalId = setInterval(async () => {

            const currentTime = new Date().getTime();
            console.log('polling function called at '+currentTime);
            if(currentTime - this.pollingStartTime > this.maxPollingDurationInMiliSec )
            {
                clearInterval(this.intervalId);
                Toast.show({
                                    label:'Error',
                                    message:`Polling timed out. Please try again`,
                                    variant: 'error',
                                    mode: 'sticky'
                            },this);
                this.pollingStarted = false;            
            }
            else
            {
                try
                {
                    const response = await checkDeviceAuthenticationStatus({device_code:this.deviceCode});
                    console.log(JSON.stringify(response));

                    if(response && response.isSuccess)
                    {
                        clearInterval(this.intervalId);
                        this.pollingStarted = false;
                        Toast.show({
                                        label:'Success',
                                        message:`Authentication successful. You can now close this window`,
                                        variant: 'success',
                                        mode: 'sticky'
                                    });
                    }
                }
                catch(error)
                {
                    console.log(error.body.message);
                    this.pollingStarted = false;
                }
            }

        }, this.pollingInterval);
    }
}