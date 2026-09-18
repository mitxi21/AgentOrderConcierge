public with sharing class OCC_ExplainOrderWorkflow {

    // Phase 10: the agent answers order-workflow questions by having a multimodal model READ the
    // workflow diagram image. The image is the File linked to this Knowledge article and is
    // resolved here at question time, so the agent never chooses which image is read and never
    // gets a text transcription of it.
    // Not final: UrlName uniqueness is checked against real org articles even inside a test, so
    // tests create their article under a different name.
    @TestVisible static String articleUrlName = 'how-an-order-moves-through-keyburn';
    @TestVisible static final String TEMPLATE_NAME = 'OCC_Order_Workflow_Diagram';
    // The template replies with exactly this when the diagram doesn't answer the question.
    @TestVisible static final String NOT_IN_DIAGRAM = 'NOT_IN_DIAGRAM';

    // Tests can't call the LLM: they set the model's reply here and read back which File was sent.
    @TestVisible static String stubbedGeneration;
    @TestVisible static Id lastDiagramId;

    public class Request {
        @InvocableVariable(label='Question' description='The caller\'s question about how an order moves through Keyburn, in their words.' required=true)
        public String question;
    }

    public class Response {
        @InvocableVariable(label='Answered' description='True if the order workflow diagram answers the question. False means nothing from the diagram applies.')
        public Boolean answered;

        @InvocableVariable(label='Message' description='The answer read from the order workflow diagram, or why there is none - safe to relay to the customer as-is.')
        public String message;
    }

    @InvocableMethod(label='Explain Order Workflow' description='Answers how an order moves through Keyburn (Draft, Processing, Shipped, Delivered, Cancelled) by reading the order workflow diagram image in Knowledge.' category='Order Case Concierge')
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(explain(req));
        }
        return results;
    }

    private static Response explain(Request req) {
        Response resp = new Response();
        resp.answered = false;
        try {
            List<Knowledge__kav> articles = [
                SELECT Id FROM Knowledge__kav
                WHERE UrlName = :articleUrlName AND PublishStatus = 'Online' AND Language = 'en_US'
                WITH USER_MODE LIMIT 1
            ];
            if (articles.isEmpty()) {
                resp.message = 'I can\'t find our order workflow guide right now.';
                return resp;
            }
            List<ContentDocumentLink> diagrams = [
                SELECT ContentDocumentId FROM ContentDocumentLink
                WHERE LinkedEntityId = :articles[0].Id
                AND ContentDocument.FileExtension IN ('png', 'jpg', 'jpeg')
                WITH USER_MODE LIMIT 1
            ];
            if (diagrams.isEmpty()) {
                resp.message = 'I can\'t find our order workflow guide right now.';
                return resp;
            }

            String answer = generate(diagrams[0].ContentDocumentId, req.question);
            if (String.isBlank(answer) || answer.contains(NOT_IN_DIAGRAM)) {
                resp.message = 'Our order workflow guide doesn\'t cover that.';
                return resp;
            }
            resp.answered = true;
            resp.message = answer.trim();
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_ExplainOrderWorkflow failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.answered = false;
            resp.message = 'I\'m having trouble reading our order workflow guide right now.';
            return resp;
        }
    }

    // The File input is passed as {"id": ContentDocumentId}; the platform sends the image to the
    // model as an attachment (fileData), and the text merge field itself renders empty.
    private static String generate(Id diagramId, String question) {
        lastDiagramId = diagramId;
        if (Test.isRunningTest()) {
            return stubbedGeneration;
        }
        ConnectApi.WrappedValue diagram = new ConnectApi.WrappedValue();
        diagram.value = new Map<String, String>{ 'id' => diagramId };
        ConnectApi.WrappedValue questionValue = new ConnectApi.WrappedValue();
        questionValue.value = question;

        ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.inputParams = new Map<String, ConnectApi.WrappedValue>{
            'Input:Diagram' => diagram,
            'Input:Question' => questionValue
        };
        input.isPreview = false;
        input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE_NAME, input);
        return output.generations.isEmpty() ? null : output.generations[0].text;
    }
}
