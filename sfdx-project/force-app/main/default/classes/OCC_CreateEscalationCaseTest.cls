@isTest
private class OCC_CreateEscalationCaseTest {

    @TestSetup
    static void setup() {
        insert new Contact(LastName = 'Doe', Email = 'jane.doe@example.com');
    }

    @isTest
    static void testCreatesHighPriorityCaseWithContact() {
        OCC_CreateEscalationCase.Request req = new OCC_CreateEscalationCase.Request();
        req.email = 'jane.doe@example.com';
        req.summary = 'Customer requested a refund; not something this agent can process.';
        req.reasonCode = 'financial_request';

        Test.startTest();
        List<OCC_CreateEscalationCase.Response> resp = OCC_CreateEscalationCase.run(new List<OCC_CreateEscalationCase.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, resp[0].caseNumber);
        Case created = [SELECT Priority, Escalation_Summary__c, ContactId FROM Case WHERE CaseNumber = :resp[0].caseNumber];
        System.assertEquals('High', created.Priority);
        System.assertNotEquals(null, created.ContactId);
    }

    @isTest
    static void testCreatesCaseWithoutEmail() {
        OCC_CreateEscalationCase.Request req = new OCC_CreateEscalationCase.Request();
        req.email = null;
        req.summary = 'Caller could not provide identifying information.';
        req.reasonCode = 'unverifiable_identity';

        Test.startTest();
        List<OCC_CreateEscalationCase.Response> resp = OCC_CreateEscalationCase.run(new List<OCC_CreateEscalationCase.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, resp[0].caseNumber);
        Case created = [SELECT Priority, ContactId FROM Case WHERE CaseNumber = :resp[0].caseNumber];
        System.assertEquals('High', created.Priority);
        System.assertEquals(null, created.ContactId);
    }
}
