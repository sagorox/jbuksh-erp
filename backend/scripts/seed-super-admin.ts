import 'reflect-metadata';
import * as bcrypt from 'bcrypt';
import { DataSource } from 'typeorm';
import { UserEntity } from '../src/users/user.entity';
import { Role } from '../src/auth/roles.enum';

const AppDataSource = new DataSource({
  type: 'mysql',
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  username: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'jbuksh_erp',
  entities: [UserEntity],
  synchronize: false,
});

async function run() {
  const phone = (process.env.SUPER_ADMIN_PHONE || '01844532895').trim();
  const fullName = (process.env.SUPER_ADMIN_NAME || 'Super Admin').trim();
  const password = (process.env.SUPER_ADMIN_PASSWORD || '123456').trim();

  if (!phone) {
    throw new Error('SUPER_ADMIN_PHONE is required');
  }

  if (!fullName) {
    throw new Error('SUPER_ADMIN_NAME is required');
  }

  if (!password || password.length < 4) {
    throw new Error('SUPER_ADMIN_PASSWORD must be at least 4 characters');
  }

  await AppDataSource.initialize();

  const repo = AppDataSource.getRepository(UserEntity);
  const existing = await repo.findOne({ where: { phone } });
  const passwordHash = await bcrypt.hash(password, 10);

  if (existing) {
    existing.full_name = fullName;
    existing.password_hash = passwordHash;
    existing.role = Role.SUPER_ADMIN;
    existing.is_active = 1;
    await repo.save(existing);

    console.log(`Updated SUPER_ADMIN: ${phone}`);
  } else {
    const user = repo.create({
      phone,
      full_name: fullName,
      password_hash: passwordHash,
      role: Role.SUPER_ADMIN,
      is_active: 1,
    });

    await repo.save(user);
    console.log(`Created SUPER_ADMIN: ${phone}`);
  }

  await AppDataSource.destroy();
  console.log('Super admin seed completed successfully.');
}

run()
  .then(() => process.exit(0))
  .catch(async (err) => {
    console.error('Super admin seed failed:', err);
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
    process.exit(1);
  });