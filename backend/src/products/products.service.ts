import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProductEntity } from './product.entity';
import { ProductBatchEntity } from './product-batch.entity';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(ProductEntity)
    private readonly repo: Repository<ProductEntity>,
    @InjectRepository(ProductBatchEntity)
    private readonly batchRepo: Repository<ProductBatchEntity>,
  ) {}

  async create(input: {
    sku: string;
    name: string;
    category_id: number;
    unit: string;
    potency_tag?: string | null;
    purchase_price: number;
    sale_price: number;
    reorder_level?: number;
    in_stock?: number;
    is_active?: number;
  }) {
    if (!input.sku?.trim()) {
      throw new BadRequestException('sku is required');
    }
    if (!input.name?.trim()) {
      throw new BadRequestException('name is required');
    }
    if (!input.category_id) {
      throw new BadRequestException('category_id is required');
    }
    if (!input.unit?.trim()) {
      throw new BadRequestException('unit is required');
    }

    const existing = await this.repo.findOne({
      where: { sku: input.sku.trim() },
    });
    if (existing) {
      throw new BadRequestException('sku already exists');
    }

    const row = this.repo.create({
      sku: input.sku.trim(),
      name: input.name.trim(),
      category_id: Number(input.category_id),
      unit: input.unit.trim(),
      potency_tag: input.potency_tag ?? null,
      purchase_price: Number(input.purchase_price ?? 0),
      sale_price: Number(input.sale_price ?? 0),
      reorder_level: Number(input.reorder_level ?? 0),
      in_stock: Number(input.in_stock ?? 0),
      is_active: Number(input.is_active ?? 1),
      version: 1,
    });

    return this.repo.save(row);
  }

  async update(
    id: number,
    input: {
      sku?: string;
      name?: string;
      category_id?: number;
      unit?: string;
      potency_tag?: string | null;
      purchase_price?: number;
      sale_price?: number;
      reorder_level?: number;
      in_stock?: number;
      is_active?: number;
    },
  ) {
    const row = await this.repo.findOne({ where: { id } });
    if (!row) {
      throw new NotFoundException('Product not found');
    }

    if (input.sku !== undefined) {
      const sku = input.sku.trim();
      if (!sku) {
        throw new BadRequestException('sku is required');
      }

      const existing = await this.repo.findOne({ where: { sku } });
      if (existing && Number(existing.id) !== Number(row.id)) {
        throw new BadRequestException('sku already exists');
      }

      row.sku = sku;
    }

    if (input.name !== undefined) {
      const name = input.name.trim();
      if (!name) {
        throw new BadRequestException('name is required');
      }
      row.name = name;
    }

    if (input.category_id !== undefined) {
      if (!input.category_id) {
        throw new BadRequestException('category_id is required');
      }
      row.category_id = Number(input.category_id);
    }

    if (input.unit !== undefined) {
      const unit = input.unit.trim();
      if (!unit) {
        throw new BadRequestException('unit is required');
      }
      row.unit = unit;
    }

    if (input.potency_tag !== undefined) {
      row.potency_tag = input.potency_tag ?? null;
    }

    if (input.purchase_price !== undefined) {
      row.purchase_price = Number(input.purchase_price ?? 0);
    }

    if (input.sale_price !== undefined) {
      row.sale_price = Number(input.sale_price ?? 0);
    }

    if (input.reorder_level !== undefined) {
      row.reorder_level = Number(input.reorder_level ?? 0);
    }

    if (input.in_stock !== undefined) {
      row.in_stock = Number(input.in_stock ?? 0);
    }

    if (input.is_active !== undefined) {
      row.is_active = Number(input.is_active);
    }

    row.version = Number(row.version || 1) + 1;

    await this.repo.save(row);
    return this.details(row.id);
  }

  list() {
    return this.repo.find({
      order: { id: 'DESC' as any },
    });
  }

  async details(id: number) {
    const row = await this.repo.findOne({ where: { id } });
    if (!row) {
      throw new NotFoundException('Product not found');
    }

    const batches = await this.batchRepo.find({
      where: { product_id: id },
      order: { exp_date: 'ASC' as any, id: 'DESC' as any },
    });

    const summary = this.buildBatchSummary(batches);

    return {
      ...row,
      batch_summary: summary,
      batches,
    };
  }

  async batchList(productId: number) {
    await this.ensureProduct(productId);

    const batches = await this.batchRepo.find({
      where: { product_id: productId },
      order: { exp_date: 'ASC' as any, id: 'DESC' as any },
    });

    return {
      ok: true,
      product_id: productId,
      summary: this.buildBatchSummary(batches),
      batches,
    };
  }

  async createBatch(
    productId: number,
    input: {
      batch_no: string;
      mfg_date?: string | null;
      exp_date?: string | null;
      qty: number;
      mrp?: number;
      purchase_price?: number;
    },
  ) {
    const product = await this.ensureProduct(productId);

    if (!input.batch_no?.trim()) {
      throw new BadRequestException('batch_no is required');
    }

    if (input.exp_date && input.mfg_date && input.mfg_date > input.exp_date) {
      throw new BadRequestException('mfg_date cannot be greater than exp_date');
    }

    const existing = await this.batchRepo.findOne({
      where: {
        product_id: productId,
        batch_no: input.batch_no.trim(),
      },
    });

    if (existing) {
      throw new BadRequestException('batch_no already exists for this product');
    }

    const batch = this.batchRepo.create({
      product_id: productId,
      batch_no: input.batch_no.trim(),
      mfg_date: input.mfg_date ?? null,
      exp_date: input.exp_date ?? null,
      qty: Number(input.qty ?? 0),
      mrp: Number(input.mrp ?? 0),
      purchase_price: Number(
        input.purchase_price ?? product.purchase_price ?? 0,
      ),
      version: 1,
    });

    const saved = await this.batchRepo.save(batch);
    await this.refreshProductStock(productId);

    return {
      ok: true,
      batch: saved,
    };
  }

  async updateBatch(
    batchId: number,
    input: {
      batch_no?: string;
      mfg_date?: string | null;
      exp_date?: string | null;
      qty?: number;
      mrp?: number;
      purchase_price?: number;
    },
  ) {
    const batch = await this.batchRepo.findOne({ where: { id: batchId } });
    if (!batch) {
      throw new NotFoundException('Product batch not found');
    }

    if (input.batch_no !== undefined) {
      const batchNo = input.batch_no.trim();
      if (!batchNo) {
        throw new BadRequestException('batch_no is required');
      }

      const exists = await this.batchRepo.findOne({
        where: {
          product_id: batch.product_id,
          batch_no: batchNo,
        },
      });

      if (exists && Number(exists.id) !== Number(batch.id)) {
        throw new BadRequestException('batch_no already exists for this product');
      }

      batch.batch_no = batchNo;
    }

    if (input.mfg_date !== undefined) {
      batch.mfg_date = input.mfg_date ?? null;
    }

    if (input.exp_date !== undefined) {
      batch.exp_date = input.exp_date ?? null;
    }

    if (batch.exp_date && batch.mfg_date && batch.mfg_date > batch.exp_date) {
      throw new BadRequestException('mfg_date cannot be greater than exp_date');
    }

    if (input.qty !== undefined) {
      batch.qty = Number(input.qty ?? 0);
    }

    if (input.mrp !== undefined) {
      batch.mrp = Number(input.mrp ?? 0);
    }

    if (input.purchase_price !== undefined) {
      batch.purchase_price = Number(input.purchase_price ?? 0);
    }

    batch.version = Number(batch.version || 1) + 1;

    const saved = await this.batchRepo.save(batch);
    await this.refreshProductStock(batch.product_id);

    return {
      ok: true,
      batch: saved,
    };
  }

  private async ensureProduct(id: number) {
    const row = await this.repo.findOne({ where: { id } });
    if (!row) {
      throw new NotFoundException('Product not found');
    }
    return row;
  }

  private async refreshProductStock(productId: number) {
    const product = await this.ensureProduct(productId);
    const batches = await this.batchRepo.find({
      where: { product_id: productId },
    });

    const totalQty = batches.reduce((sum, b) => sum + Number(b.qty || 0), 0);
    product.in_stock = Number(totalQty.toFixed(2)) as any;
    product.version = Number(product.version || 1) + 1;

    await this.repo.save(product);
  }

  private buildBatchSummary(batches: ProductBatchEntity[]) {
    const now = new Date().toISOString().substring(0, 10);

    let total_qty = 0;
    let expired_qty = 0;
    let near_expiry_qty = 0;
    let total_batches = batches.length;
    let expired_batches = 0;
    let near_expiry_batches = 0;
    let next_expiry_date: string | null = null;

    const nearExpiryDate = new Date();
    nearExpiryDate.setDate(nearExpiryDate.getDate() + 90);
    const nearExpiryLimit = nearExpiryDate.toISOString().substring(0, 10);

    for (const batch of batches) {
      const qty = Number(batch.qty || 0);
      total_qty += qty;

      if (batch.exp_date) {
        if (batch.exp_date < now) {
          expired_batches += 1;
          expired_qty += qty;
        } else if (batch.exp_date <= nearExpiryLimit) {
          near_expiry_batches += 1;
          near_expiry_qty += qty;
        }

        if (batch.exp_date >= now) {
          if (!next_expiry_date || batch.exp_date < next_expiry_date) {
            next_expiry_date = batch.exp_date;
          }
        }
      }
    }

    return {
      total_batches,
      total_qty: Number(total_qty.toFixed(2)),
      expired_batches,
      expired_qty: Number(expired_qty.toFixed(2)),
      near_expiry_batches,
      near_expiry_qty: Number(near_expiry_qty.toFixed(2)),
      next_expiry_date,
    };
  }
}