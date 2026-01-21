import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Organization } from '../../organizations/entities/organization.entity';
import { CryptoTransformer } from '../../utils/crypto.transformer';

export enum AssetType {
  PAGE = 'page',
  INSTAGRAM = 'instagram',
}

@Entity('connected_assets')
export class ConnectedAsset {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  organization_id: string;

  @Column({
    type: 'enum',
    enum: AssetType,
  })
  asset_type: AssetType;

  @Column()
  meta_asset_id: string;

  @Column()
  name: string;

  @Column({
    type: 'text',
    transformer: new CryptoTransformer(),
  })
  access_token: string;

  @ManyToOne(() => Organization, (organization) => organization.assets)
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;
}
