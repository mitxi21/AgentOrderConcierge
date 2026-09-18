@isTest
private class OCC_CheckReturnEligibilityTest {

    @TestSetup
    static void setup() {
        Contact c = new Contact(LastName = 'Smith', Email = 'john.smith@example.com');
        insert c;
        insert new Order__c(
            Order_Number__c = 'ORD-2077',
            Status__c = 'Delivered',
            Item__c = 'Mechanical Keyboard',
            Order_Date__c = Date.today().addDays(-3),
            Return_Eligible__c = true,
            Contact__c = c.Id
        );
        insert new Order__c(
            Order_Number__c = 'ORD-1042',
            Status__c = 'Shipped',
            Item__c = 'Wireless Headphones',
            Order_Date__c = Date.today().addDays(-40),
            Return_Eligible__c = false,
            Contact__c = c.Id
        );
    }

    @isTest
    static void testEligible() {
        OCC_CheckReturnEligibility.Request req = new OCC_CheckReturnEligibility.Request();
        req.email = 'john.smith@example.com';
        req.orderNumber = 'ORD-2077';

        Test.startTest();
        List<OCC_CheckReturnEligibility.Response> resp = OCC_CheckReturnEligibility.run(new List<OCC_CheckReturnEligibility.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, resp[0].found);
        System.assertEquals(true, resp[0].eligible);
        System.assertEquals('john.smith@example.com', resp[0].verifiedEmail);
    }

    @isTest
    static void testNotEligible() {
        OCC_CheckReturnEligibility.Request req = new OCC_CheckReturnEligibility.Request();
        req.email = 'john.smith@example.com';
        req.orderNumber = 'ORD-1042';

        Test.startTest();
        List<OCC_CheckReturnEligibility.Response> resp = OCC_CheckReturnEligibility.run(new List<OCC_CheckReturnEligibility.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, resp[0].found);
        System.assertEquals(false, resp[0].eligible);
    }

    @isTest
    static void testEligibleDigitsOnly() {
        // Caller speaks just the digits, no "ORD-" prefix - same normalization as case numbers.
        OCC_CheckReturnEligibility.Request req = new OCC_CheckReturnEligibility.Request();
        req.email = 'john.smith@example.com';
        req.orderNumber = '2077';

        Test.startTest();
        List<OCC_CheckReturnEligibility.Response> resp = OCC_CheckReturnEligibility.run(new List<OCC_CheckReturnEligibility.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, resp[0].found);
        System.assertEquals(true, resp[0].eligible);
    }
}
