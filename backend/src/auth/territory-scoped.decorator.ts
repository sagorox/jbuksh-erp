import { SetMetadata } from '@nestjs/common';

export const TERRITORY_SCOPED_KEY = 'territory_scoped';
export const TerritoryScoped = () => SetMetadata(TERRITORY_SCOPED_KEY, true);