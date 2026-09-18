/**
 * Shared delivery-route and static-map logic: Google Routes API for the driving leg, Google Maps
 * Static API for the picture. Used by the agent action (OCC_GetOrderDeliveryInfo), the record-page
 * component (OCC_OrderMapController) and the external page endpoint (OCC_OrderMapRest), so the three
 * surfaces can never drift apart.
 *
 * The Agentforce chat cannot render images on the current planner, so every visual surface builds
 * the map from this class instead of receiving it from the agent.
 */
public with sharing class OCC_DeliveryMap {

    private static final String ROUTES_ENDPOINT = 'https://routes.googleapis.com/directions/v2:computeRoutes';
    private static final String STATIC_MAP_ENDPOINT = 'https://maps.googleapis.com/maps/api/staticmap';
    private static final Integer CALLOUT_TIMEOUT_MS = 10000;
    private static final Double EARTH_RADIUS_KM = 6371.0;
    private static final Decimal DEFAULT_SPEED_KMH = 35;

    public class Leg {
        public Decimal distanceKm;
        public Integer minutes;
        public String polyline;
        public Boolean estimated = false;
    }

    public static Keyburn_Setting__mdt settings() {
        List<Keyburn_Setting__mdt> found = [
            SELECT Warehouse_Label__c, Warehouse_Latitude__c, Warehouse_Longitude__c,
                   Google_Maps_Api_Key__c, Average_Speed_Kmh__c
            FROM Keyburn_Setting__mdt WHERE DeveloperName = 'Default' LIMIT 1
        ];
        return found.isEmpty() ? null : found[0];
    }

    /**
     * Drives origin -> via -> destination in one Routes call. The polyline covers the whole journey
     * (that is what the map draws); the LAST leg is what is still to drive, which is what the
     * customer is told. Falls back to a straight-line estimate, flagged as such, if the call fails.
     */
    public static Leg route(Decimal originLat, Decimal originLng, Decimal viaLat, Decimal viaLng,
                            Decimal toLat, Decimal toLng, Keyburn_Setting__mdt config) {
        String apiKey = config == null ? null : config.Google_Maps_Api_Key__c;
        if (String.isNotBlank(apiKey)) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(ROUTES_ENDPOINT);
                req.setMethod('POST');
                req.setTimeout(CALLOUT_TIMEOUT_MS);
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('X-Goog-Api-Key', apiKey);
                req.setHeader('X-Goog-FieldMask', 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.duration,routes.legs.distanceMeters');
                req.setBody(routeRequestBody(originLat, originLng, viaLat, viaLng, toLat, toLng));

                HttpResponse resp = new Http().send(req);
                if (resp.getStatusCode() == 200) {
                    Leg parsed = parseRoute(resp.getBody());
                    if (parsed != null) {
                        return parsed;
                    }
                }
                System.debug(LoggingLevel.ERROR, 'Routes API returned ' + resp.getStatusCode() + ': ' + resp.getBody());
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Routes API callout failed: ' + e.getMessage());
            }
        }
        Leg leg = new Leg();
        leg.distanceKm = haversineKm(viaLat, viaLng, toLat, toLng);
        Decimal speed = (config != null && config.Average_Speed_Kmh__c != null && config.Average_Speed_Kmh__c > 0)
            ? config.Average_Speed_Kmh__c : DEFAULT_SPEED_KMH;
        leg.minutes = Integer.valueOf((leg.distanceKm / speed * 60).setScale(0, System.RoundingMode.HALF_UP));
        if (leg.minutes < 1) {
            leg.minutes = 1;
        }
        leg.estimated = true;
        return leg;
    }

    /** Warehouse (W), parcel (O) and delivery address (D) with the route drawn between them. */
    public static String staticMapUrl(Keyburn_Setting__mdt config, Decimal orderLat, Decimal orderLng,
                                      Decimal destLat, Decimal destLng, String polyline, String size) {
        String apiKey = config == null ? '' : config.Google_Maps_Api_Key__c;
        // format=png is explicit because the rich link response infers image/jpeg when it can't
        // tell the type from the URL (there is no file extension on a static-map URL).
        String url = STATIC_MAP_ENDPOINT + '?format=png&size=' + (String.isBlank(size) ? '640x400' : size) + '&scale=2'
            + '&markers=' + EncodingUtil.urlEncode('color:blue|label:W|' + coord(config == null ? null : config.Warehouse_Latitude__c, config == null ? null : config.Warehouse_Longitude__c), 'UTF-8')
            + '&markers=' + EncodingUtil.urlEncode('color:red|label:O|' + coord(orderLat, orderLng), 'UTF-8')
            + '&markers=' + EncodingUtil.urlEncode('color:green|label:D|' + coord(destLat, destLng), 'UTF-8');
        if (String.isNotBlank(polyline)) {
            url += '&path=' + EncodingUtil.urlEncode('color:0x1076dfcc|weight:5|enc:' + polyline, 'UTF-8');
        }
        return url + '&key=' + EncodingUtil.urlEncode(apiKey, 'UTF-8');
    }

    /**
     * Interactive Google Maps directions for the same journey as the static image: warehouse ->
     * parcel -> delivery address. Opened in a new tab from the record page; no API key needed.
     */
    public static String directionsUrl(Keyburn_Setting__mdt config, Decimal orderLat, Decimal orderLng,
                                       Decimal destLat, Decimal destLng) {
        Boolean hasWarehouse = config != null && config.Warehouse_Latitude__c != null && config.Warehouse_Longitude__c != null;
        String origin = hasWarehouse
            ? coord(config.Warehouse_Latitude__c, config.Warehouse_Longitude__c)
            : coord(orderLat, orderLng);
        String url = 'https://www.google.com/maps/dir/?api=1'
            + '&origin=' + EncodingUtil.urlEncode(origin, 'UTF-8')
            + '&destination=' + EncodingUtil.urlEncode(coord(destLat, destLng), 'UTF-8')
            + '&travelmode=driving';
        if (hasWarehouse) {
            url += '&waypoints=' + EncodingUtil.urlEncode(coord(orderLat, orderLng), 'UTF-8');
        }
        return url;
    }

    public static String ageInWords(Datetime reportedAt) {
        if (reportedAt == null) {
            return null;
        }
        Long minutes = (Datetime.now().getTime() - reportedAt.getTime()) / 60000;
        if (minutes < 1) {
            return 'just now';
        }
        if (minutes == 1) {
            return 'a minute ago';
        }
        if (minutes < 60) {
            return minutes + ' minutes ago';
        }
        Long hours = minutes / 60;
        return hours == 1 ? 'an hour ago' : hours + ' hours ago';
    }

    @TestVisible
    private static String routeRequestBody(Decimal originLat, Decimal originLng, Decimal viaLat, Decimal viaLng,
                                           Decimal toLat, Decimal toLng) {
        Boolean hasOrigin = originLat != null && originLng != null;
        JSONGenerator gen = JSON.createGenerator(false);
        gen.writeStartObject();
        // Without a warehouse origin configured, fall back to a single leg from the parcel onwards.
        writeWaypoint(gen, 'origin', hasOrigin ? originLat : viaLat, hasOrigin ? originLng : viaLng);
        if (hasOrigin) {
            gen.writeFieldName('intermediates');
            gen.writeStartArray();
            writeWaypointObject(gen, viaLat, viaLng);
            gen.writeEndArray();
        }
        writeWaypoint(gen, 'destination', toLat, toLng);
        gen.writeStringField('travelMode', 'DRIVE');
        gen.writeStringField('routingPreference', 'TRAFFIC_AWARE');
        gen.writeEndObject();
        return gen.getAsString();
    }

    private static void writeWaypoint(JSONGenerator gen, String name, Decimal lat, Decimal lng) {
        gen.writeFieldName(name);
        writeWaypointObject(gen, lat, lng);
    }

    private static void writeWaypointObject(JSONGenerator gen, Decimal lat, Decimal lng) {
        gen.writeStartObject();
        gen.writeFieldName('location');
        gen.writeStartObject();
        gen.writeFieldName('latLng');
        gen.writeStartObject();
        gen.writeNumberField('latitude', lat);
        gen.writeNumberField('longitude', lng);
        gen.writeEndObject();
        gen.writeEndObject();
        gen.writeEndObject();
    }

    @TestVisible
    private static Leg parseRoute(String body) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> routes = (List<Object>) parsed.get('routes');
        if (routes == null || routes.isEmpty()) {
            return null;
        }
        Map<String, Object> route = (Map<String, Object>) routes[0];
        Leg leg = new Leg();

        Map<String, Object> remaining = route;
        List<Object> legs = (List<Object>) route.get('legs');
        if (legs != null && !legs.isEmpty()) {
            remaining = (Map<String, Object>) legs[legs.size() - 1];
        }

        Object meters = remaining.get('distanceMeters');
        leg.distanceKm = meters == null ? 0 : (Decimal.valueOf(String.valueOf(meters)) / 1000).setScale(1);

        // Routes API returns duration as a protobuf duration string, e.g. "1745s".
        String duration = (String) remaining.get('duration');
        Integer seconds = 0;
        if (String.isNotBlank(duration)) {
            seconds = Integer.valueOf(duration.removeEnd('s'));
        }
        leg.minutes = Integer.valueOf(Decimal.valueOf(seconds).divide(60, 0, System.RoundingMode.HALF_UP));
        if (leg.minutes < 1) {
            leg.minutes = 1;
        }

        Map<String, Object> polyline = (Map<String, Object>) route.get('polyline');
        if (polyline != null) {
            leg.polyline = (String) polyline.get('encodedPolyline');
        }
        return leg;
    }

    private static String coord(Decimal lat, Decimal lng) {
        if (lat == null || lng == null) {
            return '';
        }
        return String.valueOf(lat.setScale(6)) + ',' + String.valueOf(lng.setScale(6));
    }

    @TestVisible
    private static Decimal haversineKm(Decimal lat1, Decimal lng1, Decimal lat2, Decimal lng2) {
        Double rLat1 = toRadians(lat1);
        Double rLat2 = toRadians(lat2);
        Double dLat = toRadians(lat2 - lat1);
        Double dLng = toRadians(lng2 - lng1);
        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(rLat1) * Math.cos(rLat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Decimal.valueOf(EARTH_RADIUS_KM * c).setScale(1);
    }

    private static Double toRadians(Decimal degrees) {
        return degrees.doubleValue() * Math.PI / 180;
    }
}
