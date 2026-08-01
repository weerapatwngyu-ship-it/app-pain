import { BadGatewayException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NearbyQueryDto } from './dto/nearby-query.dto';
import { NearbyPharmacy } from './entities/nearby-pharmacy';

const EARTH_RADIUS_METERS = 6371000;

interface GooglePlacesResult {
  place_id: string;
  name: string;
  vicinity?: string;
  geometry: { location: { lat: number; lng: number } };
  opening_hours?: { open_now?: boolean };
}

interface GooglePlacesResponse {
  status: string;
  error_message?: string;
  results: GooglePlacesResult[];
}

@Injectable()
export class PharmaciesService {
  constructor(private readonly config: ConfigService) {}

  async findNearby(query: NearbyQueryDto): Promise<NearbyPharmacy[]> {
    const apiKey = this.config.get<string>('GOOGLE_MAPS_API_KEY');
    if (!apiKey) {
      throw new ServiceUnavailableException(
        'ยังไม่ได้ตั้งค่า GOOGLE_MAPS_API_KEY ใน backend/.env — ฟีเจอร์ค้นหาร้านยาใกล้ฉันจึงยังใช้งานไม่ได้',
      );
    }

    const radius = query.radiusMeters ?? 1500;
    const url = new URL('https://maps.googleapis.com/maps/api/place/nearbysearch/json');
    url.searchParams.set('location', `${query.lat},${query.lng}`);
    url.searchParams.set('radius', String(radius));
    url.searchParams.set('type', 'pharmacy');
    url.searchParams.set('key', apiKey);

    const response = await fetch(url);
    const body = (await response.json()) as GooglePlacesResponse;

    if (body.status === 'ZERO_RESULTS') return [];
    if (body.status !== 'OK') {
      throw new BadGatewayException(
        `Google Places API error: ${body.status}${body.error_message ? ` — ${body.error_message}` : ''}`,
      );
    }

    return body.results
      .map((place) => ({
        placeId: place.place_id,
        name: place.name,
        address: place.vicinity ?? '',
        lat: place.geometry.location.lat,
        lng: place.geometry.location.lng,
        distanceMeters: Math.round(
          this.haversineMeters(query.lat, query.lng, place.geometry.location.lat, place.geometry.location.lng),
        ),
        openNow: place.opening_hours?.open_now ?? null,
      }))
      .sort((a, b) => a.distanceMeters - b.distanceMeters);
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
