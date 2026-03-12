import { IsArray, IsISO8601, IsOptional, IsString, IsNumber, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

// SyncOp defines the operation type: UPSERT (Update/Insert) or DELETE
export type SyncOp = 'UPSERT' | 'DELETE';

export class SyncChangeDto {
  @IsString()
  entity: string;

  @IsString()
  op: SyncOp;

  @IsString()
  uuid: string;

  @IsOptional()
  @IsNumber()
  version?: number;

  // payload contains entity-specific data (e.g., invoice details)
  @IsOptional()
  payload?: any;
}

export class SyncPushDto {
  @IsString()
  deviceId: string;

  @IsOptional()
  @IsISO8601()
  lastSyncAt?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncChangeDto)
  changes: SyncChangeDto[];
}