import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

/// Uploaded images live in the database rather than on disk: hosted free
/// tiers (Render et al) give containers an ephemeral filesystem, so files
/// written next to the app disappear on every restart and redeploy.
@Entity('uploaded_images')
export class UploadedImage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  mimeType: string;

  @Column({ type: 'bytea' })
  data: Buffer;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  createdAt: Date;
}
