public with sharing class OCC_PolicyFAQLookup {

    public class Request {
        @InvocableVariable(label='Query' description='The customer question or topic to search Policy/FAQ articles for.' required=true)
        public String query;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True if a relevant Policy/FAQ article was located.')
        public Boolean found;

        @InvocableVariable(label='Title' description='The matched article title.')
        public String title;

        @InvocableVariable(label='Article Body' description='The matched article content - answer using only this text, never general knowledge.')
        public String articleBody;

        @InvocableVariable(label='Message' description='Not-found explanation when no article matches - safe to relay to the customer as-is.')
        public String message;
    }

    // Small stopword set so a full spoken question ("How long does standard
    // shipping take?") reduces to the words that actually distinguish one
    // Policy/FAQ article from another ("standard", "shipping", "take").
    private static final Set<String> STOPWORDS = new Set<String>{
        'a','an','the','is','are','was','were','do','does','did','can','could',
        'will','would','should','what','when','where','how','why','who','my',
        'your','you','i','me','to','for','of','on','in','it','its','this',
        'that','and','or','about','please','have','has','had'
    };

    @InvocableMethod(label='Policy FAQ Lookup' description='Searches published Policy/FAQ Knowledge articles for content relevant to the customer\'s question and returns the best match.' category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(search(req));
        }
        return results;
    }

    private static Response search(Request req) {
        Response resp = new Response();
        try {
            String soslTerm = buildSoslTerm(req.query);

            if (String.isBlank(soslTerm)) {
                resp.found = false;
                resp.message = 'I don\'t have specific information about that.';
                return resp;
            }

            List<List<SObject>> searchResults = [
                FIND :soslTerm IN ALL FIELDS
                RETURNING Knowledge__kav(
                    Title, Summary, Article_Body__c
                    WHERE PublishStatus = 'Online' AND Language = 'en_US'
                    ORDER BY LastPublishedDate DESC
                    LIMIT 3
                )
                WITH USER_MODE
            ];

            List<Knowledge__kav> articles = (List<Knowledge__kav>) searchResults[0];
            if (articles.isEmpty()) {
                resp.found = false;
                resp.message = 'I don\'t have specific information about that.';
                return resp;
            }

            Knowledge__kav best = articles[0];
            resp.found = true;
            resp.title = best.Title;
            resp.articleBody = best.Article_Body__c;
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_PolicyFAQLookup failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.found = false;
            resp.message = 'I\'m having trouble searching that right now.';
            return resp;
        }
    }

    private static String buildSoslTerm(String query) {
        if (String.isBlank(query)) {
            return null;
        }
        List<String> terms = new List<String>();
        for (String word : query.toLowerCase().split('[^a-z0-9]+')) {
            if (String.isNotBlank(word) && word.length() > 2 && !STOPWORDS.contains(word)) {
                terms.add(word + '*');
            }
        }
        if (terms.isEmpty()) {
            return null;
        }
        return String.join(terms, ' OR ');
    }
}
