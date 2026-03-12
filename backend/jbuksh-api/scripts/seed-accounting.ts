import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { AccountingVoucherEntity } from '../src/accounting/accounting-voucher.entity';
import { UserEntity } from '../src/users/user.entity';

const AppDataSource = new DataSource({
  type: 'mysql',
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  username: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'jbuksh_erp',
  entities: [AccountingVoucherEntity, UserEntity],
  synchronize: false,
});

async function nextVoucherNo(ds: DataSource) {
  const repo = ds.getRepository(AccountingVoucherEntity);
  const count = await repo.count();
  return `VCH-${String(count + 1).padStart(6, '0')}`;
}

async function run() {
  await AppDataSource.initialize();

  const userRepo = AppDataSource.getRepository(UserEntity);
  const voucherRepo = AppDataSource.getRepository(AccountingVoucherEntity);

  const superAdmin = await userRepo.findOne({
    where: { phone: process.env.SUPER_ADMIN_PHONE || '01844532895' },
  });

  if (!superAdmin) {
    throw new Error('Super admin not found. Run seed:super-admin first.');
  }

  const today = new Date().toISOString().slice(0, 10);

  const voucher1 = voucherRepo.create({
    voucher_no: await nextVoucherNo(AppDataSource),
    voucher_date: today,
    voucher_type: 'DEBIT',
    amount: 1500,
    territory_id: null,
    party_id: null,
    user_id: superAdmin.id,
    reference_type: 'manual',
    reference_id: null,
    description: 'Opening debit voucher',
    status: 'POSTED',
    approved_at: new Date(),
    created_by: superAdmin.id,
    version: 1,
  });

  await voucherRepo.save(voucher1);

  const voucher2 = voucherRepo.create({
    voucher_no: await nextVoucherNo(AppDataSource),
    voucher_date: today,
    voucher_type: 'CREDIT',
    amount: 750,
    territory_id: null,
    party_id: null,
    user_id: superAdmin.id,
    reference_type: 'manual',
    reference_id: null,
    description: 'Opening credit voucher',
    status: 'DRAFT',
    approved_at: null,
    created_by: superAdmin.id,
    version: 1,
  });

  await voucherRepo.save(voucher2);

  console.log('Inserted sample accounting vouchers successfully.');

  await AppDataSource.destroy();
}

run()
  .then(() => process.exit(0))
  .catch(async (err) => {
    console.error('Accounting seed failed:', err);
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
    }
    process.exit(1);
  });