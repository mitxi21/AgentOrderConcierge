@isTest
private class OCC_UpdateCaseTest {

    @TestSetup
    static void setup() {
        Contact c = new Contact(LastName = 'Doe', Email = 'jane.doe@example.com');
        insert c;
        insert new Case(Subject = 'Order arrived damaged', Status = 'Working', ContactId = c.Id);
    }

    @isTest
    static void testAddComment() {
        Case inserted = [SELECT Id, CaseNumber FROM Case LIMIT 1];

        OCC_UpdateCase.Request req = new OCC_UpdateCase.Request();
        req.email = 'jane.doe@example.com';
        req.caseNumber = String.valueOf(Integer.valueOf(inserted.CaseNumber));
        req.comment = 'Customer called back to confirm the details.';

        Test.startTest();
        List<OCC_UpdateCase.Response> resp = OCC_UpdateCase.run(new List<OCC_UpdateCase.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, resp[0].success);
        List<CaseComment> comments = [SELECT CommentBody FROM CaseComment WHERE ParentId = :inserted.Id];
        System.assertEquals(1, comments.size());
        System.assertEquals('Customer called back to confirm the details.', comments[0].CommentBody);
    }

    @isTest
    static void testCaseNotFound() {
        OCC_UpdateCase.Request req = new OCC_UpdateCase.Request();
        req.email = 'jane.doe@example.com';
        req.caseNumber = '99999999';
        req.comment = 'Should not be added.';

        Test.startTest();
        List<OCC_UpdateCase.Response> resp = OCC_UpdateCase.run(new List<OCC_UpdateCase.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, resp[0].success);
    }
}
