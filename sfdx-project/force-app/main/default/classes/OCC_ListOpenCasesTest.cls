@isTest
private class OCC_ListOpenCasesTest {

    @TestSetup
    static void setup() {
        Contact jane = new Contact(LastName = 'Doe', Email = 'jane.doe@example.com');
        Contact maria = new Contact(LastName = 'Garcia', Email = 'maria.garcia@example.com');
        Contact john = new Contact(LastName = 'Smith', Email = 'john.smith@example.com');
        insert new List<Contact>{ jane, maria, john };

        insert new List<Order__c>{
            new Order__c(Order_Number__c = 'ORD-1042', Status__c = 'Shipped', Item__c = 'Wireless Headphones', Contact__c = jane.Id),
            new Order__c(Order_Number__c = 'ORD-1038', Status__c = 'Processing', Item__c = 'Tablet Stand', Contact__c = maria.Id),
            new Order__c(Order_Number__c = 'ORD-2077', Status__c = 'Delivered', Item__c = 'Mechanical Keyboard', Contact__c = john.Id)
        };

        insert new List<Case>{
            new Case(Subject = 'Order arrived damaged', Status = 'Working', Priority = 'High', ContactId = jane.Id),
            new Case(Subject = 'Follow-up: still unresolved', Status = 'Working', Priority = 'High', ContactId = jane.Id),
            new Case(Subject = 'Shipping delay inquiry', Status = 'Closed', Priority = 'Low', ContactId = maria.Id)
        };
    }

    private static OCC_ListOpenCases.Response call(String email, String identifier) {
        OCC_ListOpenCases.Request req = new OCC_ListOpenCases.Request();
        req.email = email;
        req.verifyingIdentifier = identifier;
        return OCC_ListOpenCases.run(new List<OCC_ListOpenCases.Request>{ req })[0];
    }

    @isTest
    static void testOpenCasesListedWhenVerifiedByOrderNumber() {
        Test.startTest();
        // Spoken digits only, no ORD prefix.
        OCC_ListOpenCases.Response resp = call('jane.doe@example.com', '1042');
        Test.stopTest();

        System.assertEquals(true, resp.verified);
        System.assertEquals('jane.doe@example.com', resp.verifiedEmail);
        System.assertEquals(2, resp.openCaseCount);
        System.assert(resp.message.contains('2 open cases'), resp.message);
        System.assert(resp.message.contains('Order arrived damaged'), resp.message);
    }

    @isTest
    static void testVerifiedByCaseNumber() {
        Case janeCase = [SELECT CaseNumber FROM Case WHERE Subject = 'Order arrived damaged' LIMIT 1];

        Test.startTest();
        OCC_ListOpenCases.Response resp = call('jane.doe@example.com', janeCase.CaseNumber);
        Test.stopTest();

        System.assertEquals(true, resp.verified);
        System.assertEquals(2, resp.openCaseCount);
    }

    @isTest
    static void testNoOpenCasesClosedOnesIgnored() {
        Test.startTest();
        OCC_ListOpenCases.Response resp = call('maria.garcia@example.com', 'ORD-1038');
        Test.stopTest();

        System.assertEquals(true, resp.verified);
        System.assertEquals(0, resp.openCaseCount);
        System.assertEquals('You don\'t have any open cases.', resp.message);
    }

    @isTest
    static void testAnotherCustomersOrderDoesNotVerify() {
        Test.startTest();
        // Real email, real order number - but the order belongs to John, not Jane.
        OCC_ListOpenCases.Response resp = call('jane.doe@example.com', 'ORD-2077');
        Test.stopTest();

        System.assertEquals(false, resp.verified);
        System.assertEquals(null, resp.verifiedEmail, 'A failed verification must never lock the conversation to an email');
        System.assertEquals(0, resp.openCaseCount);
        System.assert(!resp.message.contains('damaged'), 'Must not leak case details when unverified');
    }

    @isTest
    static void testEscalationSubjectIsSpokenAndCarriesNoReasonCode() {
        // Escalations are named by OCC_CreateEscalationCase, so the stored subject is already
        // caller-safe and is read back as-is. The old masking is gone; this asserts the guarantee
        // that replaced it - no internal code can reach the caller, because none is ever stored.
        Contact jane = [SELECT Id FROM Contact WHERE Email = 'jane.doe@example.com' LIMIT 1];
        Case escalation = OCC_CreateEscalationCase.named('financial_request');
        escalation.Priority = 'High';
        escalation.ContactId = jane.Id;
        insert escalation;

        Test.startTest();
        OCC_ListOpenCases.Response resp = call('jane.doe@example.com', 'ORD-1042');
        Test.stopTest();

        System.assertEquals(3, resp.openCaseCount);
        System.assert(resp.message.contains('Refund request'), resp.message);
        System.assert(!resp.message.contains('financial_request'), resp.message);
        System.assert(!resp.message.contains('Agent escalation'), resp.message);
    }

    @isTest
    static void testMissingIdentifierDoesNotVerify() {
        Test.startTest();
        OCC_ListOpenCases.Response resp = call('jane.doe@example.com', '');
        Test.stopTest();

        System.assertEquals(false, resp.verified);
    }
}
