import { ForbiddenException } from '@nestjs/common';
import { Role } from './auth/roles.enum';

export type JwtUser = {
  phone: null;
  sub?: number;
  id?: number;
  role?: Role | string;
  territory_ids?: number[];
};

export function getUserId(user?: JwtUser | null): number {
  return Number(user?.sub ?? user?.id ?? 0);
}

export function getRole(user?: JwtUser | null): string {
  return String(user?.role ?? '').toUpperCase();
}

export function isSuperAdmin(user?: JwtUser | null): boolean {
  return getRole(user) === Role.SUPER_ADMIN;
}

export function isMpo(user?: JwtUser | null): boolean {
  return getRole(user) === Role.MPO;
}

export function territoryIds(user?: JwtUser | null, scopeTerritoryIds?: number[] | null): number[] | null {
  if (scopeTerritoryIds === null || isSuperAdmin(user)) return null;
  const raw = Array.isArray(scopeTerritoryIds) ? scopeTerritoryIds : user?.territory_ids;
  return Array.from(new Set((raw ?? []).map((v) => Number(v)).filter((v) => Number.isFinite(v) && v > 0)));
}

export function assertTerritoryAccess(user: JwtUser | null | undefined, territoryId: number, scopeTerritoryIds?: number[] | null) {
  const allowed = territoryIds(user, scopeTerritoryIds);
  if (allowed === null) return;
  if (!allowed.includes(Number(territoryId))) {
    throw new ForbiddenException('You do not have access to this territory');
  }
}

export function assertOwnerOrPrivileged(user: JwtUser | null | undefined, ownerUserId: number) {
  if (isSuperAdmin(user)) return;
  if (isMpo(user) && getUserId(user) !== Number(ownerUserId)) {
    throw new ForbiddenException('You can access only your own records');
  }
}
