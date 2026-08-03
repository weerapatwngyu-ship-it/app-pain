import { BadGatewayException, Injectable } from '@nestjs/common';
import { NearbyQueryDto } from './dto/nearby-query.dto';
import { NearbyPharmacy } from './entities/nearby-pharmacy';

const EARTH_RADIUS_METERS = 6371000;
const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';

interface OverpassElement {
  type: 'node' | 'way' | 'relation';
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Record<string, string>;
}

interface OverpassResponse {
  elements: OverpassElement[];
}

/** Finds nearby pharmacies and clinics via OpenStreetMap's Overpass API —
 * free, no API key or billing account needed (unlike Google Places).
 * Coverage is community-contributed so it can be sparser than Google's in
 * some areas, but it's a real, live query against OSM's `amenity=pharmacy`
 * / `amenity=clinic` / `amenity=doctors` data. */
@Injectable()
export class PharmaciesService {
  async findNearby(query: NearbyQueryDto): Promise<NearbyPharmacy[]> {
    const radius = query.radiusMeters ?? 1500;
    const around = `around:${radius},${query.lat},${query.lng}`;
    const overpassQuery = `
      [out:json][timeout:25];
      (
        node["amenity"="pharmacy"](${around});
        way["amenity"="pharmacy"](${around});
        node["amenity"="clinic"](${around});
        way["amenity"="clinic"](${around});
        node["amenity"="doctors"](${around});
        way["amenity"="doctors"](${around});
      );
      out center tags;
    `;

    const response = await fetch(OVERPASS_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'MedTrack (medication tracking app, dev/local testing)',
      },
      body: `data=${encodeURIComponent(overpassQuery)}`,
    });

    if (!response.ok) {
      throw new BadGatewayException(
        `OpenStreetMap Overpass API error: HTTP ${response.status}`,
      );
    }
    const body = (await response.json()) as OverpassResponse;

    return body.elements
      .map((el) => this.toNearbyPharmacy(el, query.lat, query.lng))
      .filter((p): p is NearbyPharmacy => p !== null)
      .sort((a, b) => a.distanceMeters - b.distanceMeters);
  }

  private toNearbyPharmacy(el: OverpassElement, originLat: number, originLng: number): NearbyPharmacy | null {
    const lat = el.lat ?? el.center?.lat;
    const lng = el.lon ?? el.center?.lon;
    if (lat === undefined || lng === undefined) return null;

    const tags = el.tags ?? {};
    const addressParts = [tags['addr:housenumber'], tags['addr:street'], tags['addr:city']]
      .filter(Boolean);
    const isPharmacy = tags.amenity === 'pharmacy';

    return {
      placeId: `${el.type}/${el.id}`,
      name: tags.name ?? (isPharmacy ? 'ร้านขายยา' : 'คลินิก'),
      address: addressParts.join(' '),
      lat,
      lng,
      distanceMeters: Math.round(this.haversineMeters(originLat, originLng, lat, lng)),
      openNow: null, // OSM's opening_hours tag is a free-text spec, not reliably parseable to a boolean
      type: isPharmacy ? 'pharmacy' : 'clinic',
    };
  }

  private haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return EARTH_RADIUS_METERS * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}
