@isTest
private class OCC_ExplainOrderWorkflowTest {

    // Creates and publishes the workflow article with a PNG File attached, as
    // scripts/create_order_workflow_article.ps1 does in the org. Returns the File's ContentDocumentId.
    private static Id createPublishedArticleWithDiagram() {
        // The real org article already owns the production UrlName, and uniqueness is checked
        // against it even in a test.
        OCC_ExplainOrderWorkflow.articleUrlName = 'occ-test-order-workflow';
        Knowledge__kav art = new Knowledge__kav(
            Title = 'How an order moves through Keyburn',
            UrlName = OCC_ExplainOrderWorkflow.articleUrlName,
            Language = 'en_US'
        );
        insert art;
        ContentVersion cv = new ContentVersion(
            Title = 'Keyburn order workflow diagram',
            PathOnClient = 'order_workflow_diagram.png',
            VersionData = Blob.valueOf('not really a png'),
            FirstPublishLocationId = art.Id
        );
        insert cv;
        Id articleId = [SELECT KnowledgeArticleId FROM Knowledge__kav WHERE Id = :art.Id].KnowledgeArticleId;
        KbManagement.PublishingService.publishArticle(articleId, true);
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    private static OCC_ExplainOrderWorkflow.Response ask(String question) {
        OCC_ExplainOrderWorkflow.Request req = new OCC_ExplainOrderWorkflow.Request();
        req.question = question;
        return OCC_ExplainOrderWorkflow.run(new List<OCC_ExplainOrderWorkflow.Request>{ req })[0];
    }

    @isTest
    static void testAnswersFromTheArticleDiagram() {
        Id diagramId = createPublishedArticleWithDiagram();
        OCC_ExplainOrderWorkflow.stubbedGeneration = '  Unsubmitted drafts are kept for 30 days, then deleted. ';

        Test.startTest();
        OCC_ExplainOrderWorkflow.Response resp = ask('What happens if I never submit my draft?');
        Test.stopTest();

        System.assertEquals(true, resp.answered);
        System.assertEquals('Unsubmitted drafts are kept for 30 days, then deleted.', resp.message);
        System.assertEquals(diagramId, OCC_ExplainOrderWorkflow.lastDiagramId,
            'The image sent to the model must be the File linked to the workflow article');
    }

    @isTest
    static void testNotInDiagramIsNotAnAnswer() {
        createPublishedArticleWithDiagram();
        OCC_ExplainOrderWorkflow.stubbedGeneration = OCC_ExplainOrderWorkflow.NOT_IN_DIAGRAM;

        Test.startTest();
        OCC_ExplainOrderWorkflow.Response resp = ask('What is your warranty?');
        Test.stopTest();

        System.assertEquals(false, resp.answered);
        System.assert(!resp.message.contains(OCC_ExplainOrderWorkflow.NOT_IN_DIAGRAM), 'The sentinel must never reach the caller');
    }

    @isTest
    static void testNoPublishedArticleSendsNothingToTheModel() {
        OCC_ExplainOrderWorkflow.stubbedGeneration = 'should not be used';

        Test.startTest();
        OCC_ExplainOrderWorkflow.Response resp = ask('What happens after I place an order?');
        Test.stopTest();

        System.assertEquals(false, resp.answered);
        System.assertEquals(null, OCC_ExplainOrderWorkflow.lastDiagramId);
        System.assertEquals('I can\'t find our order workflow guide right now.', resp.message);
    }
}
