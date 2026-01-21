import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConnectedAsset } from './entities/connected_asset.entity';

@Module({
  imports: [TypeOrmModule.forFeature([ConnectedAsset])],
  exports: [TypeOrmModule],
})
export class AssetsModule {}
