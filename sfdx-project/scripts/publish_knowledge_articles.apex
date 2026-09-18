// Publishes every Draft "Policy / FAQ Article" Knowledge article.
// Run with: sf apex run --file publish_knowledge_articles.apex --target-org devorg
// (Or paste into Developer Console > Debug > Open Execute Anonymous Window.)

List<Knowledge__kav> drafts = [
    SELECT Id, Title, KnowledgeArticleId
    FROM Knowledge__kav
    WHERE PublishStatus = 'draft'
    AND RecordType.DeveloperName = 'Policy_FAQ'
];

System.debug('Found ' + drafts.size() + ' draft article(s) to publish.');

for (Knowledge__kav art : drafts) {
    KbManagement.PublishingService.publishArticle(art.KnowledgeArticleId, true);
    System.debug('Published: ' + art.Title);
}
