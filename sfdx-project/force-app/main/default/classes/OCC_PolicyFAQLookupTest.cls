@isTest
private class OCC_PolicyFAQLookupTest {

    @TestSetup
    static void setup() {
        Knowledge__kav article = new Knowledge__kav(
            Title = 'Return Policy',
            UrlName = 'return-policy-test',
            Summary = 'How long customers have to return an item.',
            Article_Body__c = 'Most items can be returned within 30 days of the delivery date for a full refund.',
            Language = 'en_US'
        );
        insert article;
        // KnowledgeArticleId is only populated in the database, not on the inserted sObject:
        // passing article.KnowledgeArticleId directly sent null ("Invalid ID").
        Id articleId = [SELECT KnowledgeArticleId FROM Knowledge__kav WHERE Id = :article.Id].KnowledgeArticleId;
        KbManagement.PublishingService.publishArticle(articleId, true);
    }

    @isTest
    static void testFindsRelevantArticle() {
        List<Knowledge__kav> published = [SELECT Id FROM Knowledge__kav WHERE PublishStatus = 'Online' LIMIT 1];
        List<Id> fixedIds = new List<Id>();
        for (Knowledge__kav k : published) {
            fixedIds.add(k.Id);
        }
        Test.setFixedSearchResults(fixedIds);

        OCC_PolicyFAQLookup.Request req = new OCC_PolicyFAQLookup.Request();
        req.query = 'What is your return policy?';

        Test.startTest();
        List<OCC_PolicyFAQLookup.Response> resp = OCC_PolicyFAQLookup.run(new List<OCC_PolicyFAQLookup.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, resp[0].found);
        System.assertEquals('Return Policy', resp[0].title);
    }

    @isTest
    static void testNoMatchReturnsNotFound() {
        Test.setFixedSearchResults(new List<Id>());

        OCC_PolicyFAQLookup.Request req = new OCC_PolicyFAQLookup.Request();
        req.query = 'zzz nonsense zzz';

        Test.startTest();
        List<OCC_PolicyFAQLookup.Response> resp = OCC_PolicyFAQLookup.run(new List<OCC_PolicyFAQLookup.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, resp[0].found);
    }

    @isTest
    static void testBlankQuery() {
        OCC_PolicyFAQLookup.Request req = new OCC_PolicyFAQLookup.Request();
        req.query = '';

        Test.startTest();
        List<OCC_PolicyFAQLookup.Response> resp = OCC_PolicyFAQLookup.run(new List<OCC_PolicyFAQLookup.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, resp[0].found);
    }
}
