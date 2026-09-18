@isTest
private class OCC_GetOrderDeliveryInfoTest {

    private class RoutesMock implements HttpCalloutMock {
        private Integer code;
        private String body;
        RoutesMock(Integer code, String body) {
            this.code = code;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().startsWith('https://routes.googleapis.com'), req.getEndpoint());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body);
            return res;
        }
    }

    // Warehouse -> parcel -> address. Totals cover the whole journey; leg 2 is what's left to drive,
    // and that is what the caller must hear.
    private static final String ROUTE_OK =
        '{"routes":[{"distanceMeters":11000,"duration":"2600s","polyline":{"encodedPolyline":"sk{uFvwoUiH_@cA@"},'
        + '"legs":[{"distanceMeters":3990,"duration":"855s"},{"distanceMeters":7010,"duration":"1745s"}]}]}';

    @TestSetup
    static void setup() {
        Contact jane = new Contact(
            LastName = 'Doe', Email = 'jane.doe@example.com',
            MailingStreet = 'Calle de Alcala 45', MailingCity = 'Madrid', MailingPostalCode = '28014',
            MailingLatitude = 40.418500, MailingLongitude = -3.696000
        );
        Contact noGeo = new Contact(LastName = 'Chen', Email = 'alex.chen@example.com');
        insert new List<Contact>{ jane, noGeo };

        insert new List<Order__c>{
            new Order__c(Order_Number__c = 'ORD-1042', Status__c = 'Shipped', Item__c = 'Wireless Headphones',
                Contact__c = jane.Id, Current_Location__Latitude__s = 40.440000,
                Current_Location__Longitude__s = -3.692000, Location_Updated__c = Datetime.now().addMinutes(-12)),
            new Order__c(Order_Number__c = 'ORD-1050', Status__c = 'Processing', Item__c = 'Desk Lamp', Contact__c = jane.Id),
            new Order__c(Order_Number__c = 'ORD-1051', Status__c = 'Delivered', Item__c = 'Office Chair', Contact__c = jane.Id),
            new Order__c(Order_Number__c = 'ORD-1052', Status__c = 'Shipped', Item__c = 'Webcam', Contact__c = jane.Id),
            new Order__c(Order_Number__c = 'ORD-1053', Status__c = 'Shipped', Item__c = 'Monitor', Contact__c = noGeo.Id,
                Current_Location__Latitude__s = 40.440000, Current_Location__Longitude__s = -3.692000,
                Location_Updated__c = Datetime.now())
        };
    }

    private static OCC_GetOrderDeliveryInfo.Response call(String email, String orderNumber) {
        OCC_GetOrderDeliveryInfo.Request req = new OCC_GetOrderDeliveryInfo.Request();
        req.email = email;
        req.orderNumber = orderNumber;
        return OCC_GetOrderDeliveryInfo.run(new List<OCC_GetOrderDeliveryInfo.Request>{ req })[0];
    }

    @isTest
    static void testShippedOrderUsesRoutesApi() {
        Test.setMock(HttpCalloutMock.class, new RoutesMock(200, ROUTE_OK));
        Test.startTest();
        // Spoken digits only, no ORD- prefix.
        OCC_GetOrderDeliveryInfo.Response resp = call('jane.doe@example.com', '1042');
        Test.stopTest();

        System.assertEquals(true, resp.found);
        System.assertEquals('jane.doe@example.com', resp.verifiedEmail);
        System.assertEquals(true, resp.inTransit);
        System.assertEquals(false, resp.estimated, 'Live route should not be flagged as an estimate');
        System.assertEquals(7.0, resp.distanceKm, 'Must be the remaining leg, not the 11 km total');
        System.assertEquals(29, resp.driveMinutes, 'Remaining leg 1745s rounds to 29 minutes, not the 2600s total');
        System.assertEquals('12 minutes ago', resp.locationAge);
    }

    @isTest
    static void testSpokenMessageHasNoUrlOrCoordinates() {
        Test.setMock(HttpCalloutMock.class, new RoutesMock(200, ROUTE_OK));
        Test.startTest();
        OCC_GetOrderDeliveryInfo.Response resp = call('jane.doe@example.com', 'ORD-1042');
        Test.stopTest();

        System.assert(!resp.message.contains('http'), resp.message);
        System.assert(!resp.message.contains('40.4'), 'Raw coordinates must never be spoken: ' + resp.message);
        System.assert(!resp.message.contains('-3.6'), 'Raw coordinates must never be spoken: ' + resp.message);
        System.assert(resp.message.contains('minutes by car'), resp.message);
        System.assert(!resp.message.contains('map'), 'Images do not render in chat - never promise a map: ' + resp.message);
        // The map travels in its own fields, not in the spoken text.
        System.assert(resp.mapUrl.startsWith('https://maps.googleapis.com/maps/api/staticmap'), resp.mapUrl);
        // Marker and path values are percent-encoded in the URL, so compare against the decoded form.
        String decoded = EncodingUtil.urlDecode(resp.mapUrl, 'UTF-8');
        System.assert(decoded.contains('label:W'), 'warehouse marker missing: ' + decoded);
        System.assert(decoded.contains('label:O'), 'order marker missing: ' + decoded);
        System.assert(decoded.contains('label:D'), 'destination marker missing: ' + decoded);
        System.assert(decoded.contains('enc:'), 'route polyline missing: ' + decoded);

        // Rich link entry: every field populated - with only a title (v22) the chat never
        // switched to displaying results and the map card did not render.
        System.assertEquals(1, resp.itemDetails.size(), 'Exactly one rich link entry');
        OCC_GetOrderDeliveryInfo.ItemDetail entry = resp.itemDetails[0];
        System.assert(entry.linkURL.startsWith('https://www.google.com/maps/dir/?api=1'), entry.linkURL);
        System.assert(entry.linkTitle.contains('ORD-1042'), entry.linkTitle);
        System.assert(entry.linkImageURL.contains('format=png'), entry.linkImageURL);
        System.assertEquals('image/png', entry.linkImageMimeType);
        System.assert(String.isNotBlank(entry.descriptionText));

        // Custom Lightning Type payload - field names must match the CLT schema exactly.
        System.assertNotEquals(null, resp.deliveryMap, 'Map card must be populated for a tracked order');
        System.assert(resp.deliveryMap.mapImageUrl.contains('staticmap'), resp.deliveryMap.mapImageUrl);
        System.assert(resp.deliveryMap.mapImageUrl.contains('format=png'), resp.deliveryMap.mapImageUrl);
        System.assert(resp.deliveryMap.directionsUrl.startsWith('https://www.google.com/maps/dir/?api=1'), resp.deliveryMap.directionsUrl);
        System.assert(resp.deliveryMap.headline.contains('ORD-1042'), resp.deliveryMap.headline);
        System.assert(resp.deliveryMap.subtext.contains('12 minutes ago'), resp.deliveryMap.subtext);
        System.assert(resp.mapImage.startsWith('<img src="'), resp.mapImage);
    }

    @isTest
    static void testFallsBackToEstimateWhenRoutingFails() {
        Test.setMock(HttpCalloutMock.class, new RoutesMock(403, '{"error":{"message":"blocked"}}'));
        Test.startTest();
        OCC_GetOrderDeliveryInfo.Response resp = call('jane.doe@example.com', '1042');
        Test.stopTest();

        System.assertEquals(true, resp.inTransit);
        System.assertEquals(true, resp.estimated, 'A failed callout must be flagged as an estimate');
        System.assert(resp.driveMinutes > 0);
        System.assert(resp.message.contains('estimated'), resp.message);
    }

    @isTest
    static void testNotShippedOrdersAreNotTracked() {
        Test.startTest();
        OCC_GetOrderDeliveryInfo.Response processing = call('jane.doe@example.com', 'ORD-1050');
        OCC_GetOrderDeliveryInfo.Response delivered = call('jane.doe@example.com', 'ORD-1051');
        Test.stopTest();

        System.assertEquals(true, processing.found);
        System.assertEquals(false, processing.inTransit);
        System.assert(processing.message.contains('hasn\'t shipped'), processing.message);
        System.assertEquals(null, processing.driveMinutes, 'No distance may be invented for an unshipped order');
        System.assertEquals(0, processing.itemDetails.size(), 'No card for an order that is not moving');
        System.assertEquals(null, processing.deliveryMap, 'No map card for an order that is not moving');

        System.assertEquals(false, delivered.inTransit);
        System.assert(delivered.message.contains('delivered'), delivered.message);
    }

    @isTest
    static void testShippedWithoutPositionSaysSo() {
        Test.startTest();
        OCC_GetOrderDeliveryInfo.Response resp = call('jane.doe@example.com', 'ORD-1052');
        Test.stopTest();

        System.assertEquals(true, resp.found);
        System.assertEquals(false, resp.inTransit);
        System.assert(resp.message.contains('hasn\'t reported a position'), resp.message);
    }

    @isTest
    static void testMissingDeliveryCoordinatesSaysSo() {
        Test.startTest();
        OCC_GetOrderDeliveryInfo.Response resp = call('alex.chen@example.com', 'ORD-1053');
        Test.stopTest();

        System.assertEquals(true, resp.found);
        System.assertEquals(false, resp.inTransit);
        System.assert(resp.message.contains('delivery address'), resp.message);
    }

    @isTest
    static void testEmailMismatchActsAsGuardrail() {
        Test.startTest();
        OCC_GetOrderDeliveryInfo.Response resp = call('someone.else@example.com', 'ORD-1042');
        Test.stopTest();

        System.assertEquals(false, resp.found);
        System.assertEquals(false, resp.inTransit);
        System.assertEquals(null, resp.mapUrl, 'Nothing about the order may leak to an unverified caller');
        System.assertEquals(null, resp.verifiedEmail, 'A failed lookup must never lock the conversation to an email');
    }

    @isTest
    static void testHaversineAndAgeHelpers() {
        // These live in the shared service now, so the record page and the REST endpoint get the
        // same behaviour as the agent action.
        Decimal km = OCC_DeliveryMap.haversineKm(40.450000, -3.690000, 40.418500, -3.696000);
        System.assert(km > 3 && km < 5, 'Unexpected distance: ' + km);
        System.assertEquals('just now', OCC_DeliveryMap.ageInWords(Datetime.now()));
        System.assertEquals('an hour ago', OCC_DeliveryMap.ageInWords(Datetime.now().addMinutes(-61)));
        System.assertEquals(null, OCC_DeliveryMap.ageInWords(null));
    }
}
