import { LightningElement, api } from 'lwc';

/**
 * Renders the delivery map inside the Agentforce conversation, wired up by the OrderDeliveryMap
 * Custom Lightning Type (renderers for lightningDesktopGenAi and enhancedWebChat).
 *
 * The renderer passes no attribute mappings: `attributes` on a root componentOverride is rejected
 * at deploy time ("You can't add the mapImageUrl property ... unevaluatedProperties is false"), so
 * the whole schema object arrives as `value`. The individual @api properties are kept as a
 * fallback in case a target binds them directly.
 */
export default class OccOrderMapCard extends LightningElement {
    @api value;
    @api mapImageUrl;
    @api directionsUrl;
    @api headline;
    @api subtext;

    get data() {
        return this.value || {};
    }

    get image() {
        return this.mapImageUrl || this.data.mapImageUrl;
    }

    get link() {
        return this.directionsUrl || this.data.directionsUrl;
    }

    get title() {
        return this.headline || this.data.headline;
    }

    get caption() {
        return this.subtext || this.data.subtext;
    }

    get hasMap() {
        return !!this.image;
    }
}
