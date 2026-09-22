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
        Case created = [SELECT Subject, Type, Reason, Origin, Priority, Escalation_Summary__c, ContactId
                        FROM Case WHERE CaseNumber = :resp[0].caseNumber];
        System.assertEquals('High', created.Priority);
        System.assertNotEquals(null, created.ContactId);
        // The reason code must never reach the Case: a service team reads this, not the model.
        System.assertEquals('Refund request', created.Subject);
        System.assertEquals('Billing', created.Type);
        System.assertEquals('Refund request', created.Reason);
        System.assertEquals('Agentforce Agent', created.Origin);
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
        Case created = [SELECT Subject, Type, Reason, Origin, Priority, ContactId
                        FROM Case WHERE CaseNumber = :resp[0].caseNumber];
        System.assertEquals('High', created.Priority);
        System.assertEquals(null, created.ContactId);
        System.assertEquals('Unable to verify caller identity', created.Subject);
        System.assertEquals('Account', created.Type);
        System.assertEquals('Identity verification', created.Reason);
    }

    @isTest
    static void testUnknownReasonCodeFallsBackToGenericNaming() {
        // A code the mapping doesn't know (e.g. the retired 'unlogged_escalation'), or none at all,
        // must still produce a Case a human can read - never 'Agent escalation: null'.
        OCC_CreateEscalationCase.Request coded = new OCC_CreateEscalationCase.Request();
        coded.summary = 'Escalated by a safety net.';
        coded.reasonCode = 'unlogged_escalation';
        OCC_CreateEscalationCase.Request blank = new OCC_CreateEscalationCase.Request();
        blank.summary = 'No reason code supplied.';
        blank.reasonCode = null;

        Test.startTest();
        List<OCC_CreateEscalationCase.Response> resp = OCC_CreateEscalationCase.run(
            new List<OCC_CreateEscalationCase.Request>{ coded, blank });
        Test.stopTest();

        for (OCC_CreateEscalationCase.Response r : resp) {
            System.assertNotEquals(null, r.caseNumber);
            Case created = [SELECT Subject, Type, Reason, Origin FROM Case WHERE CaseNumber = :r.caseNumber];
            System.assertEquals('Customer escalation', created.Subject);
            System.assertEquals('Support', created.Type);
            System.assertEquals('Other', created.Reason);
            System.assertEquals('Agentforce Agent', created.Origin);
        }
    }

    @isTest
    static void testReasonCodeMatchingIgnoresCaseAndSpacing() {
        System.assertEquals('Refund request', OCC_CreateEscalationCase.named('  Financial_Request ').Subject);
    }
}
