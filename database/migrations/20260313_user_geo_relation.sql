-- 1) territories table এ relation columns যোগ করো
ALTER TABLE territories
  ADD COLUMN area_id BIGINT NULL AFTER id,
  ADD COLUMN district_id BIGINT NULL AFTER area_id;

-- 2) users table এ geo columns যোগ করো
ALTER TABLE users
  ADD COLUMN division_id BIGINT NULL AFTER full_name,
  ADD COLUMN district_id BIGINT NULL AFTER division_id,
  ADD COLUMN zone_id BIGINT NULL AFTER district_id,
  ADD COLUMN area_id BIGINT NULL AFTER zone_id,
  ADD COLUMN territory_id BIGINT NULL AFTER area_id;

-- 3) indexes
ALTER TABLE districts
  ADD INDEX idx_districts_division_id (division_id);

ALTER TABLE areas
  ADD INDEX idx_areas_zone_id (zone_id);

ALTER TABLE territories
  ADD INDEX idx_territories_area_id (area_id),
  ADD INDEX idx_territories_district_id (district_id);

ALTER TABLE users
  ADD INDEX idx_users_division_id (division_id),
  ADD INDEX idx_users_district_id (district_id),
  ADD INDEX idx_users_zone_id (zone_id),
  ADD INDEX idx_users_area_id (area_id),
  ADD INDEX idx_users_territory_id (territory_id);

ALTER TABLE user_territories
  ADD UNIQUE KEY uq_user_territories_user_territory (user_id, territory_id);

-- 4) foreign keys
ALTER TABLE districts
  ADD CONSTRAINT fk_districts_division
  FOREIGN KEY (division_id) REFERENCES divisions(id)
  ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE areas
  ADD CONSTRAINT fk_areas_zone
  FOREIGN KEY (zone_id) REFERENCES zones(id)
  ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE territories
  ADD CONSTRAINT fk_territories_area
  FOREIGN KEY (area_id) REFERENCES areas(id)
  ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_territories_district
  FOREIGN KEY (district_id) REFERENCES districts(id)
  ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE users
  ADD CONSTRAINT fk_users_division
  FOREIGN KEY (division_id) REFERENCES divisions(id)
  ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_users_district
  FOREIGN KEY (district_id) REFERENCES districts(id)
  ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_users_zone
  FOREIGN KEY (zone_id) REFERENCES zones(id)
  ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_users_area
  FOREIGN KEY (area_id) REFERENCES areas(id)
  ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT fk_users_territory
  FOREIGN KEY (territory_id) REFERENCES territories(id)
  ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE user_territories
  ADD CONSTRAINT fk_user_territories_user
  FOREIGN KEY (user_id) REFERENCES users(id)
  ON UPDATE CASCADE ON DELETE CASCADE,
  ADD CONSTRAINT fk_user_territories_territory
  FOREIGN KEY (territory_id) REFERENCES territories(id)
  ON UPDATE CASCADE ON DELETE CASCADE;

-- 5) existing territory rows এর area/district map আগে ঠিক করো
-- নিচের update গুলো example, real data অনুযায়ী adjust করবে
-- UPDATE territories SET area_id = 1, district_id = 1 WHERE id = 1;
-- UPDATE territories SET area_id = 2, district_id = 1 WHERE id = 3;
-- UPDATE territories SET area_id = 3, district_id = 2 WHERE id = 10;

-- 6) existing users backfill
-- যদি user_territories এ primary territory থাকে, সেখান থেকে fill করা যাবে
UPDATE users u
LEFT JOIN user_territories ut
  ON ut.user_id = u.id AND ut.is_primary = 1
LEFT JOIN territories t
  ON t.id = ut.territory_id
LEFT JOIN areas a
  ON a.id = t.area_id
LEFT JOIN zones z
  ON z.id = a.zone_id
LEFT JOIN districts d
  ON d.id = t.district_id
SET
  u.territory_id = COALESCE(u.territory_id, t.id),
  u.area_id = COALESCE(u.area_id, a.id),
  u.zone_id = COALESCE(u.zone_id, z.id),
  u.district_id = COALESCE(u.district_id, d.id),
  u.division_id = COALESCE(u.division_id, d.division_id);

-- 7) সব user row fill হয়ে গেলে NOT NULL করো
-- আগে এই query চালিয়ে null আছে কিনা দেখো:
-- SELECT id, full_name, phone FROM users
-- WHERE division_id IS NULL OR district_id IS NULL OR zone_id IS NULL OR area_id IS NULL OR territory_id IS NULL;

ALTER TABLE territories
  MODIFY COLUMN area_id BIGINT NOT NULL,
  MODIFY COLUMN district_id BIGINT NOT NULL;

ALTER TABLE users
  MODIFY COLUMN division_id BIGINT NOT NULL,
  MODIFY COLUMN district_id BIGINT NOT NULL,
  MODIFY COLUMN zone_id BIGINT NOT NULL,
  MODIFY COLUMN area_id BIGINT NOT NULL,
  MODIFY COLUMN territory_id BIGINT NOT NULL;