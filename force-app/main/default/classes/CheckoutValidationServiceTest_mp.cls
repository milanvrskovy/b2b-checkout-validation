@IsTest
class CheckoutValidationServiceTest_mp {

    @TestSetup
    static void testSetup() {
        final Account account = new Account(
            Name = 'Test Account'
        );
        insert account;

        final Contract contract = new Contract(
            AccountId = account.Id,
            StartDate = Date.today(),
            ContractTerm = 12,
            Status = 'Draft'
        );
        insert contract;

        final Order order = new Order(
            AccountId = account.Id,
            ContractId = contract.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            BillingStreet = 'Test Street',
            BillingCity = 'Test City',
            BillingCountry = 'Netherlands'
        );
        insert order;

        final Product2 product = new Product2(
            Name = 'Test Product',
            ProductCode = 'TEST1',
            IsActive = true
        );
        insert product;

        final PricebookEntry standardPricebookEntry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert standardPricebookEntry;

        final OrderItem orderItem = new OrderItem(
            OrderId = order.Id,
            Product2Id = product.Id,
            PricebookEntryId = standardPricebookEntry.Id,
            Quantity = 10,
            UnitPrice = 100
        );
        insert orderItem;
    }

    @IsTest
    static void shouldBeValidWhenAmountIsBelowThreshold() {
        final Order order = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        final CheckoutValidationResponse_mp response = CheckoutValidationService_mp.validate(order.Id);
        Test.stopTest();

        Assert.isTrue(response.isValid, 'Order below threshold should be valid');
        Assert.isTrue(response.messages.isEmpty(), 'No validation messages expected');
    }

    @IsTest
    static void shouldReturnValidationMessageForCrossingAmountThreshold() {
        final Order order = [SELECT Id FROM Order LIMIT 1];

        // Push total amount above threshold by adding a high-value order item
        final Product2 product = [SELECT Id FROM Product2 LIMIT 1];
        final PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        insert new OrderItem(
            OrderId = order.Id,
            Product2Id = product.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 10000
        );

        Test.startTest();
        final CheckoutValidationResponse_mp response = CheckoutValidationService_mp.validate(order.Id);
        Test.stopTest();

        Assert.isFalse(response.isValid, 'Order exceeding threshold should be invalid');
        Assert.isFalse(response.messages.isEmpty(), 'Validation message expected');
        Assert.isTrue(
            response.messages[0].contains('€10,000'),
            'Message should reference the threshold amount'
        );
    }

    @IsTest
    static void shouldReturnValidationMessageForEmptyOrder() {
        final Order order = [SELECT Id FROM Order LIMIT 1];
        final List<OrderItem> items = [SELECT Id FROM OrderItem WHERE OrderId = :order.Id];
        delete items;

        Test.startTest();
        final CheckoutValidationResponse_mp response = CheckoutValidationService_mp.validate(order.Id);
        Test.stopTest();

        Assert.isFalse(response.isValid, 'Empty order should be invalid');
        Assert.isFalse(response.messages.isEmpty(), 'Validation message expected');
        Assert.isTrue(
            response.messages[0].contains('no items'),
            'Message should indicate the order has no items'
        );
    }
}