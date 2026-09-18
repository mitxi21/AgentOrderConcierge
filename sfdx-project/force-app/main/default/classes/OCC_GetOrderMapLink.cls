/**
 * Rich link response (Adaptive Response Format) for the delivery map.
 *
 * Images cannot be rendered from ordinary action output in Agentforce chat on this planner, but a
 * *rich link* response maps to the Enhanced Link messaging component, which carries a title, a
 * description and an image. Structure and field names come from Salesforce Help,
 * "Adaptive Response Format: Rich Link Response" - they are fixed, do not rename them.
 *
 * Constraints from that doc worth remembering:
 *  - Service Agent only (ours is EinsteinServiceAgent).
 *  - PNG/JPEG only, one image and one URL per response; several need a rich CHOICE response.
 *  - The image URL must be publicly reachable, and the MIME type should be explicit when the URL
 *    has no file extension - a static-map URL has none.
 *  - Rich link renders on Enhanced Chat V1, Apple Messages for Business and LINE; other channels
 *    fall back to Text, so the spoken answer must stand on its own.
 */
public with sharing class OCC_GetOrderMapLink {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided for verification.' required=true)
        public String email;

        @InvocableVariable(label='Order Number' description='The order number the caller provided, e.g. ORD-1042 or just the digits.' required=true)
        public String orderNumber;
    }

    // Field names are the rich link contract.
    public class ItemDetail {
        public String linkURL;
        public String linkTitle;
        public String linkImageURL;
        public String linkImageMimeType;
        public String descriptionText;
    }

    public class Response {
        @InvocableVariable(label='Item Details' description='linkURL, linkTitle, linkImageURL, MIME type and description for the delivery map' required=true)
        public List<ItemDetail> itemDetails;

        public Response() {
            this.itemDetails = new List<ItemDetail>();
        }
    }

    @InvocableMethod(label='Get Order Map Link' description='Returns the delivery map for a shipped order as a rich link: a Google Maps route the caller can open, with the route image. Call it after telling the caller how far away their order is.' category='Order Case Concierge' callout=true)
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(mapLink(req));
        }
        return results;
    }

    private static Response mapLink(Request req) {
        Response resp = new Response();
        try {
            String email = req.email == null ? '' : req.email.trim();
            String wanted = OCC_CaseLookupUtil.normalize(req.orderNumber);

            List<Contact> contacts = [
                SELECT Id, MailingLatitude, MailingLongitude
                FROM Contact WHERE Email = :email WITH USER_MODE LIMIT 1
            ];
            if (contacts.isEmpty()) {
                return resp;
            }
            Contact caller = contacts[0];

            Order__c matched = null;
            for (Order__c o : [
                SELECT Order_Number__c, Status__c, Item__c,
                       Current_Location__Latitude__s, Current_Location__Longitude__s
                FROM Order__c WHERE Contact__c = :caller.Id WITH USER_MODE
            ]) {
                if (OCC_CaseLookupUtil.normalize(o.Order_Number__c) == wanted) {
                    matched = o;
                }
            }
            // No order, not shipped, or nothing to plot: return an empty list rather than a card
            // about an order that isn't moving.
            if (matched == null
                || matched.Status__c != 'Shipped'
                || matched.Current_Location__Latitude__s == null
                || caller.MailingLatitude == null) {
                return resp;
            }

            Keyburn_Setting__mdt config = OCC_DeliveryMap.settings();
            OCC_DeliveryMap.Leg leg = OCC_DeliveryMap.route(
                config == null ? null : config.Warehouse_Latitude__c,
                config == null ? null : config.Warehouse_Longitude__c,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                caller.MailingLatitude, caller.MailingLongitude, config
            );

            ItemDetail detail = new ItemDetail();
            detail.linkURL = OCC_DeliveryMap.directionsUrl(config,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                caller.MailingLatitude, caller.MailingLongitude);
            detail.linkTitle = 'Order ' + matched.Order_Number__c + ' - ' + leg.distanceKm + ' km away, about ' + leg.minutes + ' min by car';
            detail.linkImageURL = OCC_DeliveryMap.staticMapUrl(config,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                caller.MailingLatitude, caller.MailingLongitude, leg.polyline, '600x300');
            detail.linkImageMimeType = 'image/png';
            detail.descriptionText = 'Here is where your ' + (String.isBlank(matched.Item__c) ? 'order' : matched.Item__c.toLowerCase()) + ' is right now.';
            resp.itemDetails.add(detail);
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_GetOrderMapLink failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return resp;
        }
    }
}
