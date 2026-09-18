/**
 * Backs the occOrderDeliveryMap LWC on the Order__c record page. Record access governs what the
 * viewing user sees (USER_MODE), so there is no email check here - unlike the agent action, where
 * the caller's identity is unverified until they give a matching email and order number.
 */
public with sharing class OCC_OrderMapController {

    public class DeliverySnapshot {
        @AuraEnabled public Boolean inTransit;
        @AuraEnabled public String message;
        @AuraEnabled public String mapUrl;
        @AuraEnabled public Decimal distanceKm;
        @AuraEnabled public Integer driveMinutes;
        @AuraEnabled public String locationAge;
        @AuraEnabled public Boolean estimated;
        @AuraEnabled public String destination;
        @AuraEnabled public String directionsUrl;
    }

    @AuraEnabled(cacheable=false)
    public static DeliverySnapshot getSnapshot(Id orderId) {
        DeliverySnapshot snap = new DeliverySnapshot();
        snap.inTransit = false;
        snap.estimated = false;
        try {
            List<Order__c> orders = [
                SELECT Order_Number__c, Status__c, Item__c,
                       Current_Location__Latitude__s, Current_Location__Longitude__s, Location_Updated__c,
                       Contact__r.Name, Contact__r.MailingStreet, Contact__r.MailingCity,
                       Contact__r.MailingLatitude, Contact__r.MailingLongitude
                FROM Order__c WHERE Id = :orderId WITH USER_MODE LIMIT 1
            ];
            if (orders.isEmpty()) {
                snap.message = 'Order not found.';
                return snap;
            }
            Order__c o = orders[0];

            if (o.Status__c != 'Shipped') {
                snap.message = 'Not in transit - this order is ' + o.Status__c.toLowerCase() + '.';
                return snap;
            }
            if (o.Current_Location__Latitude__s == null || o.Current_Location__Longitude__s == null) {
                snap.message = 'Shipped, but the carrier has not reported a position yet.';
                return snap;
            }
            if (o.Contact__c == null || o.Contact__r.MailingLatitude == null || o.Contact__r.MailingLongitude == null) {
                snap.message = 'No delivery coordinates on the contact, so the route cannot be drawn.';
                return snap;
            }

            Keyburn_Setting__mdt config = OCC_DeliveryMap.settings();
            OCC_DeliveryMap.Leg leg = OCC_DeliveryMap.route(
                config == null ? null : config.Warehouse_Latitude__c,
                config == null ? null : config.Warehouse_Longitude__c,
                o.Current_Location__Latitude__s, o.Current_Location__Longitude__s,
                o.Contact__r.MailingLatitude, o.Contact__r.MailingLongitude, config
            );

            snap.inTransit = true;
            snap.distanceKm = leg.distanceKm;
            snap.driveMinutes = leg.minutes;
            snap.estimated = leg.estimated;
            snap.locationAge = OCC_DeliveryMap.ageInWords(o.Location_Updated__c);
            snap.destination = String.isBlank(o.Contact__r.MailingStreet)
                ? o.Contact__r.Name
                : o.Contact__r.MailingStreet + ', ' + o.Contact__r.MailingCity;
            snap.mapUrl = OCC_DeliveryMap.staticMapUrl(config,
                o.Current_Location__Latitude__s, o.Current_Location__Longitude__s,
                o.Contact__r.MailingLatitude, o.Contact__r.MailingLongitude, leg.polyline, '640x360');
            snap.directionsUrl = OCC_DeliveryMap.directionsUrl(config,
                o.Current_Location__Latitude__s, o.Current_Location__Longitude__s,
                o.Contact__r.MailingLatitude, o.Contact__r.MailingLongitude);
            snap.message = leg.distanceKm + ' km away, about ' + leg.minutes + ' min by car'
                + (leg.estimated ? ' (estimated)' : '') + '.';
            return snap;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'OCC_OrderMapController failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            snap.message = 'Could not build the delivery map right now.';
            return snap;
        }
    }
}
