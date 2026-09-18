// Phase 9 demo data. Idempotent - safe to re-run after any data reload.
//   sf apex run --file scripts/set_demo_geodata.apex --target-org devorg
//
// 1. Gives the five demo contacts a Madrid mailing address with explicit coordinates. Explicit,
//    because org geocoding rules are asynchronous and unreliable in a dev org.
// 2. For every Shipped order belonging to them, drops the parcel somewhere along the way from the
//    warehouse to that customer, with a recent Location_Updated__c.
// No secrets here: the warehouse origin and the API key live in Keyburn_Setting__mdt.

Keyburn_Setting__mdt config = [
    SELECT Warehouse_Latitude__c, Warehouse_Longitude__c
    FROM Keyburn_Setting__mdt WHERE DeveloperName = 'Default' LIMIT 1
];
Decimal warehouseLat = config.Warehouse_Latitude__c;
Decimal warehouseLng = config.Warehouse_Longitude__c;

// email => { street, city, postalCode, latitude, longitude, fractionTravelled }
Map<String, List<Object>> demo = new Map<String, List<Object>>{
    'jane.doe@example.com'     => new List<Object>{ 'Calle de Alcala 45',        'Madrid', '28014', 40.418500, -3.696000, 0.62 },
    'john.smith@example.com'   => new List<Object>{ 'Gran Via 28',               'Madrid', '28013', 40.420300, -3.705800, 0.45 },
    'maria.garcia@example.com' => new List<Object>{ 'Paseo de la Castellana 200','Madrid', '28046', 40.465000, -3.690000, 0.75 },
    'alex.chen@example.com'    => new List<Object>{ 'Calle de Serrano 41',       'Madrid', '28001', 40.427000, -3.687000, 0.30 },
    'sara.connor@example.com'  => new List<Object>{ 'Avenida de America 12',     'Madrid', '28002', 40.438000, -3.676000, 0.55 }
};

List<Contact> contacts = [SELECT Id, Email FROM Contact WHERE Email IN :demo.keySet()];
Map<Id, List<Object>> byContactId = new Map<Id, List<Object>>();
for (Contact c : contacts) {
    List<Object> d = demo.get(c.Email);
    c.MailingStreet = (String) d[0];
    c.MailingCity = (String) d[1];
    c.MailingPostalCode = (String) d[2];
    c.MailingCountry = 'Spain';
    c.MailingLatitude = (Decimal) d[3];
    c.MailingLongitude = (Decimal) d[4];
    byContactId.put(c.Id, d);
}
update contacts;

List<Order__c> shipped = [
    SELECT Id, Order_Number__c, Contact__c
    FROM Order__c
    WHERE Status__c = 'Shipped' AND Contact__c IN :byContactId.keySet()
];
Integer minutesAgo = 4;
for (Order__c o : shipped) {
    List<Object> d = byContactId.get(o.Contact__c);
    Decimal destLat = (Decimal) d[3];
    Decimal destLng = (Decimal) d[4];
    Decimal travelled = (Decimal) d[5];
    // Straight-line interpolation is fine for demo data: the Routes API snaps to roads anyway.
    o.Current_Location__Latitude__s = (warehouseLat + (destLat - warehouseLat) * travelled).setScale(6);
    o.Current_Location__Longitude__s = (warehouseLng + (destLng - warehouseLng) * travelled).setScale(6);
    o.Location_Updated__c = Datetime.now().addMinutes(-minutesAgo);
    minutesAgo = Math.mod(minutesAgo + 7, 40) + 3;
}
update shipped;

System.debug('Contacts updated: ' + contacts.size() + ', shipped orders positioned: ' + shipped.size());
