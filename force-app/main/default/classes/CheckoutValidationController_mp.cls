public with sharing class CheckoutValidationController_mp {

    @AuraEnabled
    public static CheckoutValidationResponse_mp validateOrder(Id orderId) {
        try {
            return CheckoutValidationService_mp.validate(orderId);
        } catch (Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
}