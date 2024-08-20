import Toast from 'lightning/toast';

export function toUpper(name) {
    return name.toUpperCase();
}

export function showToastMessage(whichThis, labelVal, messageVal, variantVal, modeVal){
    Toast.show({
        label:labelVal,
        message:messageVal,
        variant:variantVal,
        mode:modeVal

    }, whichThis);
}