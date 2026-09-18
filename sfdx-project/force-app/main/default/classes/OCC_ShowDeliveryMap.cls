/**
 * Display-only companion to OCC_GetOrderDeliveryInfo: returns just the map card for an order.
 *
 * The agent chains it with `run` straight after GetOrderDeliveryInfo, so the card no longer depends
 * on the model choosing to call the platform display tool - which it did for the first tracked order
 * in a conversation but never for a second one (agent v31-v33). Verification and the identity lock
 * are the same as the tracking action's, because it delegates to it.
 */
public with sharing class OCC_ShowDeliveryMap {

    public class Request {
        @InvocableVariable(label='Customer Email' description='The verified email of this conversation.' required=true)
        public String email;

        @InvocableVariable(label='Order Number' description='The order just tracked, e.g. ORD-1042.' required=true)
        public String orderNumber;

        @InvocableVariable(label='Locked Email' description='Email verified earlier in this conversation, bound by the agent. When set, any other email is refused.')
        public String lockedEmail;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True if a map card was produced for this order.')
        public Boolean found;

        @InvocableVariable(label='Delivery Map' description='Map card rendered by the OrderDeliveryMapCard Custom Lightning Type.')
        public OCC_GetOrderDeliveryInfo.DeliveryMapCard deliveryMap;
    }

    @InvocableMethod(label='Show Delivery Map' description='Shows the map card for an order that is on its way. Display only - says nothing.' category='Order Case Concierge' callout=true)
    public static List<Response> run(List<Request> requests) {
        List<OCC_GetOrderDeliveryInfo.Request> tracking = new List<OCC_GetOrderDeliveryInfo.Request>();
        for (Request req : requests) {
            OCC_GetOrderDeliveryInfo.Request t = new OCC_GetOrderDeliveryInfo.Request();
            t.email = req.email;
            t.orderNumber = req.orderNumber;
            t.lockedEmail = req.lockedEmail;
            tracking.add(t);
        }
        List<Response> results = new List<Response>();
        for (OCC_GetOrderDeliveryInfo.Response tracked : OCC_GetOrderDeliveryInfo.run(tracking)) {
            Response resp = new Response();
            resp.deliveryMap = tracked.deliveryMap;
            resp.found = tracked.deliveryMap != null;
            results.add(resp);
        }
        return results;
    }
}
