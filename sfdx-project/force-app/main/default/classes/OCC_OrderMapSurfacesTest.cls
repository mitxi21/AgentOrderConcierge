@isTest
private class OCC_OrderMapSurfacesTest {

    private class RoutesMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"routes":[{"distanceMeters":11000,"duration":"2600s",'
                + '"polyline":{"encodedPolyline":"sk{uFvwoUiH_@cA@"},'
                + '"legs":[{"distanceMeters":3990,"duration":"855s"},{"distanceMeters":7010,"duration":"1745s"}]}]}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Contact jane = new Contact(
            LastName = 'Doe', Email = 'jane.doe@example.com',
            MailingStreet = 'Calle de Alcala 45', MailingCity = 'Madrid',
            MailingLatitude = 40.418500, MailingLongitude = -3.696000
        );
        Contact john = new Contact(LastName = 'Smith', Email = 'john.smith@example.com');
        insert new List<Contact>{ jane, john };

        insert new List<Order__c>{
            new Order__c(Order_Number__c = 'ORD-1042', Status__c = 'Shipped', Item__c = 'Wireless Headphones',
                Contact__c = jane.Id, Current_Location__Latitude__s = 40.430470,
                Current_Location__Longitude__s = -3.693720, Location_Updated__c = Datetime.now().addMinutes(-9)),
            new Order__c(Order_Number__c = 'ORD-1050', Status__c = 'Processing', Item__c = 'Desk Lamp', Contact__c = jane.Id),
            new Order__c(Order_Number__c = 'ORD-2077', Status__c = 'Shipped', Item__c = 'Keyboard', Contact__c = john.Id,
                Current_Location__Latitude__s = 40.44, Current_Location__Longitude__s = -3.69)
        };
    }

    private static Id orderId(String orderNumber) {
        return [SELECT Id FROM Order__c WHERE Order_Number__c = :orderNumber LIMIT 1].Id;
    }

    // ---- record page controller ----

    @isTest
    static void testControllerReturnsMapForShippedOrder() {
        Test.setMock(HttpCalloutMock.class, new RoutesMock());
        Test.startTest();
        OCC_OrderMapController.DeliverySnapshot snap = OCC_OrderMapController.getSnapshot(orderId('ORD-1042'));
        Test.stopTest();

        System.assertEquals(true, snap.inTransit);
        System.assertEquals(7.0, snap.distanceKm, 'Remaining leg, not the total');
        System.assertEquals(29, snap.driveMinutes);
        System.assertEquals(false, snap.estimated);
        System.assert(snap.mapUrl.startsWith('https://maps.googleapis.com/maps/api/staticmap'), snap.mapUrl);
        System.assert(snap.destination.contains('Calle de Alcala 45'), snap.destination);
        System.assertEquals('9 minutes ago', snap.locationAge);
        // The image links out to the same journey in Google Maps: warehouse -> parcel -> address.
        System.assert(snap.directionsUrl.startsWith('https://www.google.com/maps/dir/?api=1'), snap.directionsUrl);
        String decoded = EncodingUtil.urlDecode(snap.directionsUrl, 'UTF-8');
        System.assert(decoded.contains('origin=40.450000,-3.690000'), 'Route should start at the warehouse: ' + decoded);
        System.assert(decoded.contains('waypoints=40.430470,-3.693720'), 'Route should pass through the parcel: ' + decoded);
        System.assert(decoded.contains('destination=40.418500,-3.696000'), 'Route should end at the customer: ' + decoded);
        System.assert(!snap.directionsUrl.contains('key='), 'The interactive link needs no API key');
    }

    @isTest
    static void testControllerSaysWhyThereIsNoMap() {
        Test.startTest();
        OCC_OrderMapController.DeliverySnapshot processing = OCC_OrderMapController.getSnapshot(orderId('ORD-1050'));
        OCC_OrderMapController.DeliverySnapshot noGeo = OCC_OrderMapController.getSnapshot(orderId('ORD-2077'));
        Test.stopTest();

        System.assertEquals(false, processing.inTransit);
        System.assertEquals(null, processing.mapUrl);
        System.assert(processing.message.contains('processing'), processing.message);

        System.assertEquals(false, noGeo.inTransit, 'No delivery coordinates means no route');
        System.assert(noGeo.message.contains('delivery coordinates'), noGeo.message);
    }

    // ---- REST endpoint for the external page ----

    private static OCC_OrderMapRest.MapResponse callRest(String email, String orderNumber) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/keyburn/ordermap';
        req.httpMethod = 'GET';
        if (email != null) { req.addParameter('email', email); }
        if (orderNumber != null) { req.addParameter('orderNumber', orderNumber); }
        RestContext.request = req;
        RestContext.response = new RestResponse();
        return OCC_OrderMapRest.getOrderMap();
    }

    @isTest
    static void testRestReturnsMapForVerifiedCaller() {
        Test.setMock(HttpCalloutMock.class, new RoutesMock());
        Test.startTest();
        OCC_OrderMapRest.MapResponse resp = callRest('jane.doe@example.com', '1042');
        Test.stopTest();

        System.assertEquals(true, resp.found);
        System.assertEquals(true, resp.inTransit);
        System.assertEquals(7.0, resp.distanceKm);
        System.assert(resp.mapUrl.contains('staticmap'), resp.mapUrl);
        System.assert(resp.directionsUrl.startsWith('https://www.google.com/maps/dir/?api=1'), resp.directionsUrl);
        System.assert(!resp.directionsUrl.contains('key='), 'The interactive link needs no API key');
    }

    @isTest
    static void testRestRefusesAnotherCustomersOrder() {
        Test.startTest();
        // Real email, real order number - but ORD-2077 is John's.
        OCC_OrderMapRest.MapResponse resp = callRest('jane.doe@example.com', 'ORD-2077');
        Test.stopTest();

        System.assertEquals(false, resp.found);
        System.assertEquals(null, resp.mapUrl, 'No map may be built for an order the caller cannot prove is theirs');
        System.assertEquals(null, resp.directionsUrl, 'No directions for an unverified order either');
    }

    @isTest
    static void testRestRequiresBothParameters() {
        Test.startTest();
        OCC_OrderMapRest.MapResponse noEmail = callRest(null, '1042');
        OCC_OrderMapRest.MapResponse noOrder = callRest('jane.doe@example.com', null);
        Test.stopTest();

        System.assertEquals(false, noEmail.found);
        System.assertEquals(false, noOrder.found);
        System.assert(noEmail.message.contains('required'), noEmail.message);
    }
}
