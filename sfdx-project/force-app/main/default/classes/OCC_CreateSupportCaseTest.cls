@isTest
private class OCC_CreateSupportCaseTest {

    @TestSetup
    static void setup() {
        Contact maria = new Contact(LastName = 'Garcia', Email = 'maria.garcia@example.com');
        Contact john = new Contact(LastName = 'Smith', Email = 'john.smith@example.com');
        insert new List<Contact>{ maria, john };

        insert new List<Order__c>{
            new Order__c(Order_Number__c = 'ORD-1038', Status__c = 'Processing', Item__c = 'Tablet Stand', Contact__c = maria.Id),
            new Order__c(Order_Number__c = 'ORD-2077', Status__c = 'Delivered', Item__c = 'Mechanical Keyboard', Contact__c = john.Id)
        };
    }

    private static OCC_CreateSupportCase.Response call(String email, String identifier, String summary) {
        OCC_CreateSupportCase.Request req = new OCC_CreateSupportCase.Request();
        req.email = email;
        req.verifyingIdentifier = identifier;
        req.issueSummary = summary;
        return OCC_CreateSupportCase.run(new List<OCC_CreateSupportCase.Request>{ req })[0];
    }

    @isTest
    static void testCaseCreatedForVerifiedCaller() {
        Test.startTest();
        OCC_CreateSupportCase.Response resp = call('maria.garcia@example.com', '1038', 'Tablet stand order has not shipped yet');
        Test.stopTest();

        System.assertEquals(true, resp.success);
        System.assertEquals('maria.garcia@example.com', resp.verifiedEmail);
        System.assertNotEquals(null, resp.caseNumber);
        System.assert(resp.message.contains(resp.caseNumber), resp.message);

        Contact maria = [SELECT Id FROM Contact WHERE Email = 'maria.garcia@example.com' LIMIT 1];
        Case created = [SELECT Subject, Priority, ContactId FROM Case WHERE CaseNumber = :resp.caseNumber];
        System.assertEquals('Tablet stand order has not shipped yet', created.Subject);
        System.assertEquals('Medium', created.Priority);
        System.assertEquals(maria.Id, created.ContactId);
    }

    @isTest
    static void testUnverifiedCallerCreatesNothing() {
        Test.startTest();
        // Order belongs to John, not Maria.
        OCC_CreateSupportCase.Response resp = call('maria.garcia@example.com', 'ORD-2077', 'Something');
        Test.stopTest();

        System.assertEquals(false, resp.success);
        System.assertEquals(null, resp.caseNumber);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }

    @isTest
    static void testBlankSummaryCreatesNothing() {
        Test.startTest();
        OCC_CreateSupportCase.Response resp = call('maria.garcia@example.com', 'ORD-1038', '  ');
        Test.stopTest();

        System.assertEquals(false, resp.success);
        System.assertEquals(0, [SELECT COUNT() FROM Case]);
    }
}
