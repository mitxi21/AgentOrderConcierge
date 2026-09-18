@isTest
private class OCC_GetOrderStatusTest {

    @TestSetup
    static void setup() {
        Contact c = new Contact(LastName = 'Doe', Email = 'jane.doe@example.com');
        insert c;
        insert new Order__c(
            Order_Number__c = 'ORD-1042',
            Status__c = 'Shipped',
            Item__c = 'Wireless Headphones',
            Order_Date__c = Date.today().addDays(-5),
            Estimated_Delivery__c = Date.today().addDays(2),
            Return_Eligible__c = false,
            Contact__c = c.Id
        );
    }

    @isTest
    static void testFoundOrder() {
        OCC_GetOrderStatus.Request req = new OCC_GetOrderStatus.Request();
        req.email = 'jane.doe@example.com';
        req.orderNumber = 'ORD-1042';

        Test.startTest();
        List<OCC_GetOrderStatus.Response> resp = OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, resp[0].found);
        System.assertEquals('Shipped', resp[0].status);
        System.assertEquals('Wireless Headphones', resp[0].item);
        System.assertEquals('jane.doe@example.com', resp[0].verifiedEmail, 'The agent locks the conversation to this email');
    }

    @isTest
    static void testDatesAreIsoNotLocaleFormatted() {
        // Date.format() would give "9/11/2026" for en_US but "11/09/2026" for es_ES - ambiguous to the LLM.
        OCC_GetOrderStatus.Request req = new OCC_GetOrderStatus.Request();
        req.email = 'jane.doe@example.com';
        req.orderNumber = 'ORD-1042';

        Test.startTest();
        List<OCC_GetOrderStatus.Response> resp = OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ req });
        Test.stopTest();

        Pattern iso = Pattern.compile('\\d{4}-\\d{2}-\\d{2}');
        System.assert(iso.matcher(resp[0].estimatedDelivery).matches(), resp[0].estimatedDelivery);
        System.assert(iso.matcher(resp[0].orderDate).matches(), resp[0].orderDate);
        System.assertEquals(String.valueOf(Date.today().addDays(2)), resp[0].estimatedDelivery);
    }

    @isTest
    static void testFoundOrderDigitsOnly() {
        // Caller speaks just the digits, no "ORD-" prefix - same normalization as case numbers.
        OCC_GetOrderStatus.Request req = new OCC_GetOrderStatus.Request();
        req.email = 'jane.doe@example.com';
        req.orderNumber = '1042';

        Test.startTest();
        List<OCC_GetOrderStatus.Response> resp = OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, resp[0].found);
        System.assertEquals('Shipped', resp[0].status);
    }

    @isTest
    static void testDraftOrderIsNotSubmittedAndPromisesNoDate() {
        Contact jane = [SELECT Id FROM Contact WHERE Email = 'jane.doe@example.com' LIMIT 1];
        insert new Order__c(Order_Number__c = 'ORD-1100', Status__c = 'Draft', Item__c = 'USB-C Hub',
            Estimated_Delivery__c = Date.today().addDays(7), Contact__c = jane.Id);

        OCC_GetOrderStatus.Request req = new OCC_GetOrderStatus.Request();
        req.email = 'jane.doe@example.com';
        req.orderNumber = '1100';

        Test.startTest();
        OCC_GetOrderStatus.Response resp = OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(true, resp.found);
        System.assertEquals('Draft', resp.status);
        System.assert(resp.message.contains('hasn\'t been submitted'), resp.message);
        System.assertEquals(null, resp.estimatedDelivery, 'A draft was never placed, so no delivery date is promised');
    }

    @isTest
    static void testNotFound() {
        OCC_GetOrderStatus.Request req = new OCC_GetOrderStatus.Request();
        req.email = 'jane.doe@example.com';
        req.orderNumber = 'ORD-9999';

        Test.startTest();
        List<OCC_GetOrderStatus.Response> resp = OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, resp[0].found);
    }

    @isTest
    static void testEmailMismatchActsAsGuardrail() {
        OCC_GetOrderStatus.Request req = new OCC_GetOrderStatus.Request();
        req.email = 'someone.else@example.com';
        req.orderNumber = 'ORD-1042';

        Test.startTest();
        List<OCC_GetOrderStatus.Response> resp = OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, resp[0].found);
        System.assertEquals(null, resp[0].verifiedEmail, 'A failed lookup must never lock the conversation to an email');
        System.assertEquals(false, resp[0].identityLocked);
    }

    @isTest
    static void testLockedConversationRefusesAnotherEmail() {
        // A second, real customer with a real order - but the conversation is locked to Jane.
        Contact maria = new Contact(LastName = 'Garcia', Email = 'maria.garcia@example.com');
        insert maria;
        insert new Order__c(Order_Number__c = 'ORD-1088', Status__c = 'Shipped', Item__c = 'Lamp', Contact__c = maria.Id);

        OCC_GetOrderStatus.Request req = new OCC_GetOrderStatus.Request();
        req.email = 'maria.garcia@example.com';
        req.orderNumber = '1088';
        req.lockedEmail = 'jane.doe@example.com';

        Test.startTest();
        OCC_GetOrderStatus.Response resp = OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(false, resp.found);
        System.assertEquals(null, resp.status, 'Nothing about Maria\'s order may leak');
        System.assertEquals(OCC_CaseLookupUtil.LOCK_REFUSAL, resp.message);
        System.assertEquals('jane.doe@example.com', resp.verifiedEmail, 'A refused lookup must keep the lock');
        System.assertEquals(true, resp.identityLocked);
    }

    @isTest
    static void testLockedConversationAllowsSameEmail() {
        OCC_GetOrderStatus.Request req = new OCC_GetOrderStatus.Request();
        req.email = 'Jane.Doe@example.com ';
        req.orderNumber = '1042';
        req.lockedEmail = 'jane.doe@example.com';

        Test.startTest();
        OCC_GetOrderStatus.Response resp = OCC_GetOrderStatus.run(new List<OCC_GetOrderStatus.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(true, resp.found, 'Case and whitespace differences are the same customer');
        System.assertEquals(true, resp.identityLocked);
    }
}
