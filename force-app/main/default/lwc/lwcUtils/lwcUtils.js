import Toast from 'lightning/toast';

export function toUpper(name) {
    return name.toUpperCase();
}

export function showToastMessage(whichThis, label, message, variant, mode){
    Toast.show({label, message, variant, mode}, whichThis);
}