@isTest
private class OCC_ShowDeliveryMapTest {

    private class RoutesMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"routes":[{"distanceMeters":11000,"duration":"2600s","polyline":{"encodedPolyline":"sk{uFvwoUiH_@cA@"},'
                + '"legs":[{"distanceMeters":3990,"duration":"855s"},{"distanceMeters":7010,"duration":"1745s"}]}]}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Contact jane = new Contact(
            LastName = 'Doe', Email = 'jane.doe@example.com',
            MailingStreet = 'Calle de Alcala 45', MailingCity = 'Madrid', MailingPostalCode = '28014',
            MailingLatitude = 40.418500, MailingLongitude = -3.696000
        );
        insert jane;
        insert new List<Order__c>{
            new Order__c(Order_Number__c = 'ORD-1042', Status__c = 'Shipped', Item__c = 'Wireless Headphones',
                Contact__c = jane.Id, Current_Location__Latitude__s = 40.440000,
                Current_Location__Longitude__s = -3.692000, Location_Updated__c = Datetime.now().addMinutes(-12)),
            new Order__c(Order_Number__c = 'ORD-1050', Status__c = 'Processing', Item__c = 'Desk Lamp', Contact__c = jane.Id)
        };
    }

    private static OCC_ShowDeliveryMap.Response call(String email, String orderNumber, String lockedEmail) {
        OCC_ShowDeliveryMap.Request req = new OCC_ShowDeliveryMap.Request();
        req.email = email;
        req.orderNumber = orderNumber;
        req.lockedEmail = lockedEmail;
        return OCC_ShowDeliveryMap.run(new List<OCC_ShowDeliveryMap.Request>{ req })[0];
    }

    @isTest
    static void testReturnsCardForTrackedOrder() {
        Test.setMock(HttpCalloutMock.class, new RoutesMock());
        Test.startTest();
        OCC_ShowDeliveryMap.Response resp = call('jane.doe@example.com', 'ORD-1042', 'jane.doe@example.com');
        Test.stopTest();

        System.assertEquals(true, resp.found);
        System.assert(resp.deliveryMap.headline.contains('ORD-1042'), resp.deliveryMap.headline);
        System.assert(resp.deliveryMap.mapImageUrl.contains('staticmap'), resp.deliveryMap.mapImageUrl);
    }

    @isTest
    static void testNoCardForOrderNotMoving() {
        Test.startTest();
        OCC_ShowDeliveryMap.Response resp = call('jane.doe@example.com', 'ORD-1050', null);
        Test.stopTest();

        System.assertEquals(false, resp.found);
        System.assertEquals(null, resp.deliveryMap);
    }

    @isTest
    static void testLockBlocksAnotherCustomer() {
        Test.startTest();
        OCC_ShowDeliveryMap.Response resp = call('jane.doe@example.com', 'ORD-1042', 'maria.garcia@example.com');
        Test.stopTest();

        System.assertEquals(false, resp.found, 'The identity lock applies to the card too');
        System.assertEquals(null, resp.deliveryMap);
    }
}
