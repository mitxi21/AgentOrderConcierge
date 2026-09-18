@isTest
private class OCC_GetOrderMapLinkTest {

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
            MailingLatitude = 40.418500, MailingLongitude = -3.696000
        );
        Contact john = new Contact(LastName = 'Smith', Email = 'john.smith@example.com');
        insert new List<Contact>{ jane, john };

        insert new List<Order__c>{
            new Order__c(Order_Number__c = 'ORD-1042', Status__c = 'Shipped', Item__c = 'Wireless Headphones',
                Contact__c = jane.Id, Current_Location__Latitude__s = 40.430470,
                Current_Location__Longitude__s = -3.693720, Location_Updated__c = Datetime.now()),
            new Order__c(Order_Number__c = 'ORD-1050', Status__c = 'Processing', Item__c = 'Desk Lamp', Contact__c = jane.Id),
            new Order__c(Order_Number__c = 'ORD-2077', Status__c = 'Shipped', Item__c = 'Keyboard', Contact__c = john.Id,
                Current_Location__Latitude__s = 40.44, Current_Location__Longitude__s = -3.69)
        };
    }

    private static OCC_GetOrderMapLink.Response call(String email, String orderNumber) {
        OCC_GetOrderMapLink.Request req = new OCC_GetOrderMapLink.Request();
        req.email = email;
        req.orderNumber = orderNumber;
        return OCC_GetOrderMapLink.run(new List<OCC_GetOrderMapLink.Request>{ req })[0];
    }

    @isTest
    static void testRichLinkForShippedOrder() {
        Test.setMock(HttpCalloutMock.class, new RoutesMock());
        Test.startTest();
        OCC_GetOrderMapLink.Response resp = call('jane.doe@example.com', '1042');
        Test.stopTest();

        System.assertEquals(1, resp.itemDetails.size(), 'Rich link carries exactly one image and URL');
        OCC_GetOrderMapLink.ItemDetail detail = resp.itemDetails[0];
        System.assert(detail.linkURL.startsWith('https://www.google.com/maps/dir/?api=1'), detail.linkURL);
        System.assert(detail.linkTitle.contains('ORD-1042'), detail.linkTitle);
        System.assert(detail.linkTitle.contains('7.0 km'), detail.linkTitle);
        System.assert(detail.linkImageURL.contains('staticmap'), detail.linkImageURL);
        // No file extension on a static-map URL, so the MIME type has to be explicit, and the
        // image has to actually be a PNG.
        System.assertEquals('image/png', detail.linkImageMimeType);
        System.assert(detail.linkImageURL.contains('format=png'), detail.linkImageURL);
        System.assert(detail.descriptionText.contains('wireless headphones'), detail.descriptionText);
    }

    @isTest
    static void testNoCardWhenNothingToTrack() {
        Test.startTest();
        OCC_GetOrderMapLink.Response processing = call('jane.doe@example.com', 'ORD-1050');
        OCC_GetOrderMapLink.Response unknown = call('jane.doe@example.com', 'ORD-9999');
        Test.stopTest();

        System.assertEquals(0, processing.itemDetails.size(), 'No card for an order that has not shipped');
        System.assertEquals(0, unknown.itemDetails.size());
    }

    @isTest
    static void testNoCardForAnotherCustomersOrder() {
        Test.startTest();
        OCC_GetOrderMapLink.Response resp = call('jane.doe@example.com', 'ORD-2077');
        Test.stopTest();

        System.assertEquals(0, resp.itemDetails.size(), 'Same verification as every other action');
    }
}
