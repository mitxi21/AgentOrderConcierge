@isTest
private class OCC_GetCaseStatusTest {

    @TestSetup
    static void setup() {
        Contact c = new Contact(LastName = 'Doe', Email = 'jane.doe@example.com');
        insert c;
        insert new Case(Subject = 'Order arrived damaged', Status = 'Working', Priority = 'High', ContactId = c.Id);
        insert new Case(Subject = 'Follow-up: still unresolved', Status = 'Working', Priority = 'High', ContactId = c.Id);
    }

    @isTest
    static void testFoundWithStrippedLeadingZeros() {
        List<Case> cases = [SELECT Id, CaseNumber FROM Case ORDER BY CreatedDate ASC];
        Case target = cases[0];
        // Simulate a caller speaking the number without leading zeros, e.g. "00001026" -> "1026".
        String spokenNumber = String.valueOf(Integer.valueOf(target.CaseNumber));

        OCC_GetCaseStatus.Request req = new OCC_GetCaseStatus.Request();
        req.email = 'jane.doe@example.com';
        req.caseNumber = spokenNumber;

        Test.startTest();
        List<OCC_GetCaseStatus.Response> resp = OCC_GetCaseStatus.run(new List<OCC_GetCaseStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, resp[0].found);
        System.assertEquals('jane.doe@example.com', resp[0].verifiedEmail);
        System.assertEquals('Working', resp[0].status);
        // The second case for the same contact is still open, so this should be 1.
        System.assertEquals(1, resp[0].openRelatedCaseCount);
    }

    @isTest
    static void testNotFound() {
        OCC_GetCaseStatus.Request req = new OCC_GetCaseStatus.Request();
        req.email = 'jane.doe@example.com';
        req.caseNumber = '99999999';

        Test.startTest();
        List<OCC_GetCaseStatus.Response> resp = OCC_GetCaseStatus.run(new List<OCC_GetCaseStatus.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, resp[0].found);
    }
}
