public with sharing class CheckoutValidationService_mp {

    public class ExtensionException extends Exception {}

    private static final Decimal MAX_ORDER_AMOUNT = 10000;
    private static final String
        CUSTOM_VALIDATION_RECORDTYPE_CONFIGURED = 'Configured',
        CUSTOM_VALIDATION_RECORDTYPE_PROGRAMMATIC = 'Programmatic';
    private static final String
        MSG_AMOUNT_EXCEEDED = 'Order total exceeds the maximum allowed amount of €10,000.',
        MSG_EMPTY_ORDER = 'Order contains no items and cannot be validated.';
    private static final String
        MSG_EXTENSION_MISSING_FLOW = 'CONFIGURATION ERROR: Extension Flow with API Name "{0}" supplied by Custom Checkout Validation "{1}" not found.',
        MSG_EXTENSION_MISSING_CLASS = 'CONFIGURATION ERROR: Extension Apex Class "{0}" supplied by Custom Checkout Validation "{1}" not found.',
        MSG_EXTENSION_MISSING_INTERFACE = 'CONFIGURATION ERROR: Extension Apex Class "{0}" supplied by Custom Checkout Validation "{1}" does not use a mandatory interface.',
        MSG_VALIDATION_OPERATOR_MISMATCH = 'CONFIGURATION ERROR: {0} - Validation Operator not applicable on Validated Field type or Validation Value.';
    private static final String
        OPERATOR_IS_EMPTY = 'Is Empty',
        OPERATOR_NOT_EMPTY = 'Not Empty',
        OPERATOR_CONTAINS = 'Contains',
        OPERATOR_EQUALS = 'Equals',
        OPERATOR_NOT_EQUALS = 'Not Equals',
        OPERATOR_GREATER_THAN = 'Greater Than',
        OPERATOR_LESS_THAN = 'Less Than';

    /**
     * Validates an Order against all core and custom validation rules.
     * @param orderId The ID of the Order to validate.
     * @return CheckoutValidationResponse_mp containing overall validity and any error messages.
     */
    public static CheckoutValidationResponse_mp validate(Id orderId) {
        final Order order = OrdersSelector_mp.selectById(new Set<Id>{orderId})[0];
        final List<String> validationMessages = new List<String>{};
        addIfPresent(validationMessages, validateOrderNotEmpty(order));
        if (!validationMessages.isEmpty()) {
            return buildResponse(validationMessages);
        }
        validationMessages.addAll(runCoreValidations(order));
        validationMessages.addAll(runCustomValidations(order));
        return buildResponse(validationMessages);
    }

    /**
     * Builds the response from a flat list of error messages.
     * An empty list produces a valid response.
     */
    private static CheckoutValidationResponse_mp buildResponse(List<String> messages) {
        return new CheckoutValidationResponse_mp(
            messages.isEmpty(),
            messages
        );
    }

    /**
     * Runs all mandatory package-defined validations.
     * Empty order check is handled upstream — not repeated here.
     */
    private static List<String> runCoreValidations(Order order) {
        final List<String> messages = new List<String>();
        addIfPresent(messages, validateAmountThreshold(order));
        return messages;
    }

    /**
     * Dispatches all active CustomCheckoutValidation__c records
     * to the appropriate handler based on record type.
     */
    private static List<String> runCustomValidations(Order order) {
        final List<String> messages = new List<String>();
        for (CustomCheckoutValidation__c rule : CustomCheckoutValidationsSelector_mp.selectActiveValidations()) {
            if (rule.RecordType.DeveloperName == CUSTOM_VALIDATION_RECORDTYPE_CONFIGURED) {
                addIfPresent(messages, runConfiguredValidation(rule, order));
            } else if (rule.RecordType.DeveloperName == CUSTOM_VALIDATION_RECORDTYPE_PROGRAMMATIC) {
                if (String.isNotBlank(rule.ApexClassName__c)) {
                    messages.addAll(runApexExtension(rule, order));
                } else if (String.isNotBlank(rule.FlowApiName__c)) {
                    messages.addAll(runFlowExtension(rule, order));
                }
            }
        }
        return messages;
    }

    /**
     * Evaluates a field/operator/value rule against the Order using dynamic field access.
     * @return Error message if the rule fails, null if it passes.
     * Returns a configuration error message on type mismatch between operator and field value.
     * NOTE: PMD cognitive complexity suppressed — complexity is inherent to operator dispatching
     * and cannot be meaningfully reduced without obscuring the logic.
     */
    @SuppressWarnings('PMD.CognitiveComplexity')
    private static String runConfiguredValidation(CustomCheckoutValidation__c rule, Order order) {
        final Object fieldValue = order.get(rule.ValidatedField__c);
        final String operator = rule.ValidationOperator__c;
        final String ruleValue = rule.ValidationValue__c;
        try {
            if (operator == OPERATOR_IS_EMPTY) { return checkIsEmpty(fieldValue) ? rule.Message__c : null; }
            if (operator == OPERATOR_NOT_EMPTY) { return checkNotEmpty(fieldValue) ? rule.Message__c : null; }
            if (operator == OPERATOR_CONTAINS) { return checkContains(fieldValue, ruleValue) ? rule.Message__c : null; }
            if (operator == OPERATOR_EQUALS) { return checkEquals(fieldValue, ruleValue) ? rule.Message__c : null; }
            if (operator == OPERATOR_NOT_EQUALS) { return checkNotEquals(fieldValue, ruleValue) ? rule.Message__c : null; }
            if (operator == OPERATOR_GREATER_THAN) { return checkGreaterThan(fieldValue, ruleValue) ? rule.Message__c : null; }
            if (operator == OPERATOR_LESS_THAN) { return checkLessThan(fieldValue, ruleValue) ? rule.Message__c : null; }
        } catch (Exception e) {
            return String.format(MSG_VALIDATION_OPERATOR_MISMATCH, new List<String>{
                rule.ValidatedField__c,
                operator,
                rule.Name
            });
        }
        return null;
    }

    /**
     * Dynamically instantiates and invokes an Apex extension via Type.forName().
     * Configuration errors (missing class, missing interface) are returned as messages.
     * Runtime exceptions thrown by the extension are intentionally allowed to bubble up.
     */
    private static List<String> runApexExtension(CustomCheckoutValidation__c rule, Order order) {
        final List<String> messages = new List<String>();
        ICheckoutValidator_mp apexExtension;
        try {
            apexExtension = (ICheckoutValidator_mp) Type.forName(rule.ApexClassName__c).newInstance();
        } catch (System.TypeException e) {
            messages.add(String.format(MSG_EXTENSION_MISSING_INTERFACE, new List<String>{
                rule.ApexClassName__c,
                rule.Name
            }));
            return messages;
        } catch (Exception e) {
            messages.add(String.format(MSG_EXTENSION_MISSING_CLASS, new List<String>{
                rule.ApexClassName__c,
                rule.Name
            }));
            return messages;
        }
        for (String message : apexExtension.validate(order)) {
            if (String.isNotBlank(message)) {
                messages.add(message);
            }
        }
        return messages;
    }

    /**
     * Invokes a Flow extension by API name, passing the Order as input.
     * Expects the Flow to expose a Text Collection output variable named 'validationMessages'.
     * Flow not found or runtime failure is returned as a configuration error message.
     */
    private static List<String> runFlowExtension(CustomCheckoutValidation__c rule, Order order) {
        final List<String> messages = new List<String>();
        try {
            final Flow.Interview flowInterview = Flow.Interview.createInterview(
                rule.FlowApiName__c,
                new Map<String, Object>{ 'order' => order }
            );
            flowInterview.start();
            final List<String> flowMessages = (List<String>) flowInterview.getVariableValue('validationMessages');
            if (flowMessages != null) {
                for (String message : flowMessages) {
                    if (String.isNotBlank(message)) {
                        messages.add(message);
                    }
                }
            }
        } catch (Exception e) {
            messages.add(String.format(MSG_EXTENSION_MISSING_FLOW, new List<String>{
                rule.FlowApiName__c,
                rule.Name
            }));
        }
        return messages;
    }

    /** @return MSG_EMPTY_ORDER if the Order has no items, null otherwise. */
    private static String validateOrderNotEmpty(Order order) {
        return order.OrderItems.isEmpty() ? MSG_EMPTY_ORDER : null;
    }

    /** @return MSG_AMOUNT_EXCEEDED if TotalAmount exceeds MAX_ORDER_AMOUNT, null otherwise. */
    private static String validateAmountThreshold(Order order) {
        return order.TotalAmount > MAX_ORDER_AMOUNT ? MSG_AMOUNT_EXCEEDED : null;
    }

    /** Adds a message to the list only when non-blank. */
    private static void addIfPresent(List<String> messages, String message) {
        if (String.isNotBlank(message)) {
            messages.add(message);
        }
    }

    private static Boolean checkIsEmpty(Object fieldValue) {
        return fieldValue == null || String.isBlank(String.valueOf(fieldValue));
    }

    private static Boolean checkNotEmpty(Object fieldValue) {
        return fieldValue != null && String.isNotBlank(String.valueOf(fieldValue));
    }

    private static Boolean checkContains(Object fieldValue, String ruleValue) {
        return String.valueOf(fieldValue).containsIgnoreCase(ruleValue);
    }

    private static Boolean checkEquals(Object fieldValue, String ruleValue) {
        return String.valueOf(fieldValue).equalsIgnoreCase(ruleValue);
    }

    private static Boolean checkNotEquals(Object fieldValue, String ruleValue) {
        return !String.valueOf(fieldValue).equalsIgnoreCase(ruleValue);
    }

    private static Boolean checkGreaterThan(Object fieldValue, String ruleValue) {
        return Decimal.valueOf(String.valueOf(fieldValue)) > Decimal.valueOf(ruleValue);
    }

    private static Boolean checkLessThan(Object fieldValue, String ruleValue) {
        return Decimal.valueOf(String.valueOf(fieldValue)) < Decimal.valueOf(ruleValue);
    }
}