export interface NearbyPharmacy {
  placeId: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
  distanceMeters: number;
  openNow: boolean | null;
}
