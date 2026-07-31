import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('patients')
export class Patient {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  ownerUserId: string;

  @Column()
  name: string;

  @Column({ type: 'date' })
  birthDate: string;

  @Column({ nullable: true })
  primaryCondition?: string;

  @Column({ nullable: true })
  gender?: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  createdAt: Date;
}
