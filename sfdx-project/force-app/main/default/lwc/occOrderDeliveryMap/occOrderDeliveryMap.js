import { LightningElement, api, track } from 'lwc';
import getSnapshot from '@salesforce/apex/OCC_OrderMapController.getSnapshot';

export default class OccOrderDeliveryMap extends LightningElement {
    @api recordId;
    @track snapshot;
    loading = true;
    error;

    connectedCallback() {
        this.load();
    }

    @api
    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            // Not cacheable: the parcel moves, and a stale map is worse than a slow one.
            this.snapshot = await getSnapshot({ orderId: this.recordId });
        } catch (e) {
            this.error = (e && e.body && e.body.message) || 'Could not load the delivery map.';
        } finally {
            this.loading = false;
        }
    }

    handleRefresh() {
        this.load();
    }

    get hasMap() {
        return !!(this.snapshot && this.snapshot.inTransit && this.snapshot.mapUrl);
    }

    get summary() {
        return this.snapshot ? this.snapshot.message : '';
    }

    get detail() {
        if (!this.hasMap) {
            return '';
        }
        const parts = [];
        if (this.snapshot.destination) {
            parts.push(`To ${this.snapshot.destination}`);
        }
        if (this.snapshot.locationAge) {
            parts.push(`position reported ${this.snapshot.locationAge}`);
        }
        if (this.snapshot.estimated) {
            parts.push('driving time estimated locally - routing service unavailable');
        }
        return parts.join(' · ');
    }
}
