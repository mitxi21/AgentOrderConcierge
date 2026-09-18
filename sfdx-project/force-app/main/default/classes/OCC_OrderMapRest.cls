/**
 * GET /services/apexrest/keyburn/ordermap?email=...&orderNumber=...
 *
 * For the Phase 11 external call page. The Agent API returns text only ("result": [] on every
 * message), so a client that wants to SHOW the delivery map has to ask for it separately. Same
 * verification as the agent action: the email must match a Contact and the order must belong to
 * that Contact, so this endpoint can never reveal an order the caller hasn't identified.
 *
 * Runs as the authenticated API user (the External Client App's Run As user).
 */
@RestResource(urlMapping='/keyburn/ordermap')
global with sharing class OCC_OrderMapRest {

    global class MapResponse {
        global Boolean found = false;
        global Boolean inTransit = false;
        global String message;
        global String mapUrl;
        global Decimal distanceKm;
        global Integer driveMinutes;
        global String locationAge;
        global Boolean estimated = false;
    }

    @HttpGet
    global static MapResponse getOrderMap() {
        RestRequest req = RestContext.request;
        String email = req.params.get('email');
        String orderNumber = req.params.get('orderNumber');
        MapResponse out = new MapResponse();
        try {
            if (String.isBlank(email) || String.isBlank(orderNumber)) {
                out.message = 'email and orderNumber are both required.';
                return out;
            }
            Id contactId = OCC_CaseLookupUtil.verifiedContactId(email, orderNumber);
            if (contactId == null) {
                // Deliberately vague: same answer for a wrong email and for someone else's order.
                out.message = 'No order was found matching that email and order number.';
                return out;
            }

            String wanted = OCC_CaseLookupUtil.normalize(orderNumber);
            Order__c matched = null;
            for (Order__c o : [
                SELECT Order_Number__c, Status__c,
                       Current_Location__Latitude__s, Current_Location__Longitude__s, Location_Updated__c,
                       Contact__r.MailingLatitude, Contact__r.MailingLongitude
                FROM Order__c WHERE Contact__c = :contactId WITH USER_MODE
            ]) {
                if (OCC_CaseLookupUtil.normalize(o.Order_Number__c) == wanted) {
                    matched = o;
                }
            }
            if (matched == null) {
                out.message = 'No order was found matching that email and order number.';
                return out;
            }
            out.found = true;

            if (matched.Status__c != 'Shipped'
                || matched.Current_Location__Latitude__s == null
                || matched.Contact__r.MailingLatitude == null) {
                out.message = 'Nothing to track for this order yet.';
                return out;
            }

            Keyburn_Setting__mdt config = OCC_DeliveryMap.settings();
            OCC_DeliveryMap.Leg leg = OCC_DeliveryMap.route(
                config == null ? null : config.Warehouse_Latitude__c,
                config == null ? null : config.Warehouse_Longitude__c,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                matched.Contact__r.MailingLatitude, matched.Contact__r.MailingLongitude, config
            );

            out.inTransit = true;
            out.distanceKm = leg.distanceKm;
            out.driveMinutes = leg.minutes;
            out.estimated = leg.estimated;
            out.locationAge = OCC_DeliveryMap.ageInWords(matched.Location_Updated__c);
            out.mapUrl = OCC_DeliveryMap.staticMapUrl(config,
                matched.Current_Location__Latitude__s, matched.Current_Location__Longitude__s,
                matched.Contact__r.MailingLatitude, matched.Contact__r.MailingLongitude, leg.polyline, '800x450');
            out.message = leg.distanceKm + ' km away, about ' + leg.minutes + ' min by car.';
            return out;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_OrderMapRest failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            out.message = 'Could not build the delivery map right now.';
            return out;
        }
    }
}
