import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProductEntity } from '../products/product.entity';

@Injectable()
export class StockService {
  constructor(
    @InjectRepository(ProductEntity)
    private readonly productsRepo: Repository<ProductEntity>,
  ) {}

  async summary() {
    const items = await this.productsRepo.find({ where: { is_active: 1 } });

    const totalItems = items.length;
    const lowStockCount = items.filter((p) => Number(p.in_stock) <= Number(p.reorder_level)).length;

    const stockValue = items.reduce((sum, p) => {
      return sum + Number(p.in_stock) * Number(p.purchase_price);
    }, 0);

    return {
      ok: true,
      totalItems,
      lowStockCount,
      stockValue: Number(stockValue.toFixed(2)),
    };
  }

  async itemDetails(productId: number) {
    const p = await this.productsRepo.findOne({ where: { id: productId } });
    if (!p) throw new NotFoundException('Product not found');

    const stockValue = Number(p.in_stock) * Number(p.purchase_price);

    return {
      ok: true,
      item: {
        id: p.id,
        sku: p.sku,
        name: p.name,
        unit: p.unit,
        potency_tag: p.potency_tag,
        purchase_price: Number(p.purchase_price),
        sale_price: Number(p.sale_price),
        reorder_level: Number(p.reorder_level),
        in_stock: Number(p.in_stock),
        stock_value: Number(stockValue.toFixed(2)),
      },
    };
  }

  async adjust(input: { product_id: number; qty: number }) {
    const p = await this.productsRepo.findOne({ where: { id: input.product_id } });
    if (!p) throw new NotFoundException('Product not found');

    const next = Number(p.in_stock) + Number(input.qty);
    p.in_stock = next < 0 ? 0 : (next as any);

    await this.productsRepo.save(p);

    return {
      ok: true,
      product_id: p.id,
      in_stock: Number(p.in_stock),
    };
  }
}