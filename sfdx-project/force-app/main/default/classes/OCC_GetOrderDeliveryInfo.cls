public with sharing class OCC_GetOrderDeliveryInfo {

    public class Request {
        @InvocableVariable(label='Customer Email' description='Email address the caller provided for verification.' required=true)
        public String email;

        @InvocableVariable(label='Order Number' description='The order number the caller provided, e.g. ORD-1042 or just the digits.' required=true)
        public String orderNumber;
        @InvocableVariable(label='Locked Email' description='Email verified earlier in this conversation, bound by the agent - never asked from the caller. When set, any other email is refused.')
        public String lockedEmail;
    }

    public class Response {
        @InvocableVariable(label='Found' description='True if a matching order was located for this email and order number.')
        public Boolean found;

        @InvocableVariable(label='In Transit' description='True only when the order is shipped and has a reported position. False means there is nothing to track yet.')
        public Boolean inTransit;

        @InvocableVariable(label='Message' description='Human-readable answer, safe to read to the caller verbatim. Contains no URL and no raw coordinates.')
        public String message;

        @InvocableVariable(label='Distance Km' description='Remaining driving distance in kilometres.')
        public Decimal distanceKm;

        @InvocableVariable(label='Drive Minutes' description='Remaining driving time in minutes.')
        public Integer driveMinutes;

        @InvocableVariable(label='Location Age' description='How long ago the position was reported, in words, e.g. "12 minutes ago".')
        public String locationAge;

        @InvocableVariable(label='Map Image' description='Static map of warehouse, current position and delivery address, as rich text for display in the chat. Never read aloud.')
        public String mapImage;

        @InvocableVariable(label='Map Url' description='The static map image URL, for channels that render their own image. Never read aloud.')
        public String mapUrl;

        @InvocableVariable(label='Estimated' description='True if the driving time is a local estimate because the routing service was unavailable.')
        public Boolean estimated;

        @InvocableVariable(label='Item Details' description='Rich link payload: the route image, a title and a Google Maps URL. Pass through untouched so the card renders.')
        public List<ItemDetail> itemDetails;

        @InvocableVariable(label='Delivery Map' description='Map card rendered by the OrderDeliveryMap Custom Lightning Type. Pass through untouched.')
        public DeliveryMapCard deliveryMap;

        @InvocableVariable(label='Verified Email' description='The email that matched this lookup. Empty when nothing matched. The agent locks the conversation to it.')
        public String verifiedEmail;

        @InvocableVariable(label='Identity Locked' description='True once this conversation is pinned to a verified email.')
        public Boolean identityLocked;

        @InvocableVariable(label='Order Number' description='The matched order number, e.g. ORD-1042. Lets the agent chain OCC_ShowDeliveryMap for the same order.')
        public String orderNumber;
        // (A second, list-typed `deliveryMaps` output of the same card type existed from v19 to
        // v25 and was removed: every version published while it existed failed to render the card,
        // including a byte-identical republish of the working v16 script.)
    }

    /**
     * Matches the OrderDeliveryMap Custom Lightning Type schema field for field - the names bind to
     * `{!$attrs.<name>}` in its renderer.json, which draws the card with the occOrderMapCard LWC.
     * Unlike the rich link response, a CLT renderer works in Enhanced Web Chat (this org's channel)
     * as well as the Builder preview.
     */
    public class DeliveryMapCard {
        @InvocableVariable public String mapImageUrl;
        @InvocableVariable public String directionsUrl;
        @InvocableVariable public String headline;
        @InvocableVariable public String subtext;
    }

    /**
     * Rich link response (Adaptive Response Format). Field names are the Salesforce contract from
     * "Adaptive Response Format: Rich Link Response" - do not rename them. One image and one URL
     * per response; Service Agent only; PNG/JPEG only, and the MIME type must be explicit because a
     * static-map URL carries no file extension.
     *
     * It rides on this action rather than a separate one: a second, optional action is simply not
     * called about one time in two, and the card is what the caller is meant to see.
     */
    public class ItemDetail {
        public String linkURL;
        public String linkTitle;
        public String linkImageURL;
        public String linkImageMimeType;
        public String descriptionText;
    }

    private static final String ROUTES_ENDPOINT = 'https://routes.googleapis.com/directions/v2:computeRoutes';
    private static final String STATIC_MAP_ENDPOINT = 'https://maps.googleapis.com/maps/api/staticmap';
    private static final Integer CALLOUT_TIMEOUT_MS = 10000;
    // Double, not Decimal: the haversine maths runs in Double and Decimal.valueOf has no Decimal overload.
    private static final Double EARTH_RADIUS_KM = 6371.0;

    @InvocableMethod(label='Get Order Delivery Info' description='For a shipped order, returns how far away the parcel is, the remaining driving time, and a map of warehouse to current position to delivery address. Verified against the caller\'s email.' category='Order Case Concierge' callout=true)
    public static List<Response> run(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response r = track(req);
            r.identityLocked = String.isNotBlank(r.verifiedEmail);
            results.add(r);
        }
        return results;
    }

    private static Response track(Request req) {
        Response resp = new Response();
        resp.found = false;
        resp.inTransit = false;
        resp.estimated = false;
        resp.itemDetails = new List<ItemDetail>();
        try {
            resp.verifiedEmail = OCC_CaseLookupUtil.lockOf(req.lockedEmail);
            if (OCC_CaseLookupUtil.violatesLock(req.lockedEmail, req.email)) {
                resp.found = false;
                resp.message = OCC_CaseLookupUtil.LOCK_REFUSAL;
                return resp;
            }
            String email = req.email == null ? '' : req.email.trim();
            String wanted = OCC_CaseLookupUtil.normalize(req.orderNumber);

            List<Contact> contacts = [
                SELECT Id, MailingStreet, MailingCity, MailingPostalCode, MailingLatitude, MailingLongitude
                FROM Contact WHERE Email = :email WITH USER_MODE LIMIT 1
            ];
            if (contacts.isEmpty()) {
                resp.message = 'No customer was found with that email.';
                return resp;
            }
            Contact caller = contacts[0];

            Order__c matched = null;
            for (Order__c o : [
                SELECT Order_Number__c, Status__c, Item__c, Estimated_Delivery__c,
                       Current_Location__Latitude__s, Current_Location__Longitude__s, Location_Updated__c
                FROM Order__c WHERE Contact__c = :caller.Id WITH USER_MODE
            ]) {
                if (OCC_CaseLookupUtil.normalize(o.Order_Number__c) == wanted) {
                    matched = o;
                }
            }
            if (matched == null) {
                resp.message = 'No order was found matching that email and order number.';
                return resp;
            }
            resp.found = true;
            resp.verifiedEmail = email;
            resp.orderNumber = matched.Order_Number__c;

            if (matched.Status__c != 'Shipped') {
                resp.message = notInTransitMessage(matched);
                return resp;
            }
            if (matched.Current_Location__Latitude__s == null || matched.Current_Location__Longitude__s == null) {
                resp.message = 'Your order has shipped, but the carrier hasn\'t reported a position for it yet.';
                return resp;
            }
            if (caller.MailingLatitude == null || caller.MailingLongitude == null) {
                resp.message = 'Your order is on its way, but I don\'t have a delivery address on file precise enough to track it.';
                return resp;
            }

            Keyburn_Setting__mdt settings = OCC_DeliveryMap.settings();
            resp.inTransit = true;
            resp.locationAge = OCC_DeliveryMap.ageInWords(matched.Location_Updated__c);

            // One call, warehouse -> current position -> delivery address. The full polyline draws the
            // whole journey on the map; the second leg is what's actually left to drive.
            OCC_DeliveryMap.Leg leg = OCC_DeliveryMap.route(
                settings == null ? null : settings.Warehouse_Latitude__c,
                settings == null ? null : settings.Warehouse_Longitude__c,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                caller.MailingLatitude, caller.MailingLongitude, settings
            );
            resp.distanceKm = leg.distanceKm;
            resp.driveMinutes = leg.minutes;
            resp.estimated = leg.estimated;

            resp.mapUrl = OCC_DeliveryMap.staticMapUrl(settings,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                caller.MailingLatitude, caller.MailingLongitude, leg.polyline, null);
            resp.mapImage = '<img src="' + resp.mapUrl.escapeHtml4() + '" alt="Map showing the route from the warehouse to your delivery address" />';
            resp.message = spokenMessage(matched, leg, resp.locationAge);

            // The rich link entry is what makes Enhanced Chat V2 display results at all, which is how
            // the map card below gets drawn: without it (v21) no card, and with only a title (v22)
            // no card either - the fields must be populated. This is the exact v16 payload, the
            // only one proven to render. V2 prints these fields as text under the card.
            String directions = OCC_DeliveryMap.directionsUrl(settings,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                caller.MailingLatitude, caller.MailingLongitude);
            String staticMap = OCC_DeliveryMap.staticMapUrl(settings,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                caller.MailingLatitude, caller.MailingLongitude, leg.polyline, '600x300');
            ItemDetail card = new ItemDetail();
            card.linkURL = directions;
            card.linkTitle = 'Order ' + matched.Order_Number__c + ' - ' + leg.distanceKm + ' km away, about ' + leg.minutes + ' min by car';
            card.linkImageURL = staticMap;
            card.linkImageMimeType = 'image/png';
            card.descriptionText = 'Here is where your '
                + (String.isBlank(matched.Item__c) ? 'order' : matched.Item__c.toLowerCase()) + ' is right now.';
            resp.itemDetails.add(card);

            DeliveryMapCard mapCard = new DeliveryMapCard();
            mapCard.mapImageUrl = staticMap;
            mapCard.directionsUrl = directions;
            mapCard.headline = 'Order ' + matched.Order_Number__c + ' - ' + leg.distanceKm + ' km away, about ' + leg.minutes + ' min by car';
            mapCard.subtext = String.isBlank(resp.locationAge)
                ? 'Warehouse, parcel and delivery address'
                : 'Position reported ' + resp.locationAge;
            resp.deliveryMap = mapCard;
            return resp;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_GetOrderDeliveryInfo failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            resp.message = 'I\'m having trouble tracking that order right now.';
            return resp;
        }
    }

    private static String notInTransitMessage(Order__c o) {
        if (o.Status__c == 'Delivered') {
            return 'That order has already been delivered, so there\'s nothing left to track.';
        }
        if (o.Status__c == 'Cancelled') {
            return 'That order was cancelled, so it isn\'t on its way.';
        }
        // Processing, Draft, or anything added later: never invent a position.
        return 'That order hasn\'t shipped yet, so there\'s no delivery to track. It\'s still ' + o.Status__c.toLowerCase() + '.';
    }

    private static String spokenMessage(Order__c o, OCC_DeliveryMap.Leg leg, String age) {
        String distanceText = leg.distanceKm >= 10
            ? String.valueOf(leg.distanceKm.setScale(0)) + ' kilometres'
            : String.valueOf(leg.distanceKm.setScale(1)) + ' kilometres';
        String timeText = leg.estimated
            ? 'roughly ' + leg.minutes + ' minutes by car, estimated'
            : 'about ' + leg.minutes + ' minutes by car';
        // No "map in the chat": images don't render in Agentforce chat on this planner (confirmed
        // on v8 with rich-text output). The map lives on the Order record page and, later, the
        // Phase 11 page. Promising one the caller can't see is worse than not mentioning it.
        String ageText = String.isBlank(age) ? '' : ' That position was reported ' + age + '.';
        return 'Your order is about ' + distanceText + ' away, ' + timeText + '.' + ageText;
    }

}
