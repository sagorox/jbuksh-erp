import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { NotificationEntity } from '../src/notifications/notification.entity';
import { UserEntity } from '../src/users/user.entity';

const AppDataSource = new DataSource({
  type: 'mysql',
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  username: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'jbuksh_erp',
  entities: [NotificationEntity, UserEntity],
  synchronize: false,
});

async function run() {
  await AppDataSource.initialize();

  const userRepo = AppDataSource.getRepository(UserEntity);
  const notificationRepo = AppDataSource.getRepository(NotificationEntity);

  const superAdmin = await userRepo.findOne({
    where: { phone: process.env.SUPER_ADMIN_PHONE || '01844532895' },
  });

  if (!superAdmin) {
    throw new Error('Super admin user not found. Run seed:super-admin first.');
  }

  const rows = [
    notificationRepo.create({
      user_id: superAdmin.id,
      title: 'Welcome',
      body: 'System notification module is now active.',
      type: 'SYSTEM',
      ref_type: null,
      ref_id: null,
      is_read: 0,
      read_at: null,
    }),
    notificationRepo.create({
      user_id: superAdmin.id,
      title: 'Approval Pending',
      body: 'There are approvals waiting for review.',
      type: 'APPROVAL',
      ref_type: 'approval',
      ref_id: 1,
      is_read: 0,
      read_at: null,
    }),
    notificationRepo.create({
      user_id: superAdmin.id,
      title: 'Low Stock Alert',
      body: 'Some products are near stock-out level.',
      type: 'LOW_STOCK',
      ref_type: 'product',
      ref_id: 1,
      is_read: 0,
      read_at: null,
    }),
  ];

  await notificationRepo.save(rows);

  console.log(`Inserted ${rows.length} notifications for user: ${superAdmin.phone}`);

  await AppDataSource.destroy();
  console.log('Notification seed completed successfully.');
}

run()
  .then(() => process.exit(0))
  .catch(async (err) => {
    console.error('Notification seed failed:', err);
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
    process.exit(1);
  });