-- Migration: 20261023_0035_inventory_cost_price_support.sql
-- Description: Add optional cost_price column, make purchase_price nullable, and sync both columns bidirectionally.

-- 1. Ensure cost_price column exists on public.products and public.product_variants
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12,2);
ALTER TABLE public.product_variants ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12,2);

-- 2. Make purchase_price nullable on public.products so cost price is truly optional (NULL allowed)
ALTER TABLE public.products ALTER COLUMN purchase_price DROP NOT NULL;
ALTER TABLE public.products ALTER COLUMN purchase_price SET DEFAULT NULL;

-- 3. Populate existing data: backfill cost_price from purchase_price if empty
UPDATE public.products
SET cost_price = purchase_price
WHERE cost_price IS NULL AND purchase_price IS NOT NULL;

UPDATE public.product_variants
SET cost_price = purchase_price
WHERE cost_price IS NULL AND purchase_price IS NOT NULL;

-- 4. Bidirectional synchronization trigger for public.products
CREATE OR REPLACE FUNCTION public.sync_product_cost_price()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.cost_price IS NOT NULL AND NEW.purchase_price IS NULL THEN
    NEW.purchase_price := NEW.cost_price;
  ELSIF NEW.purchase_price IS NOT NULL AND NEW.cost_price IS NULL THEN
    NEW.cost_price := NEW.purchase_price;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_product_cost_price ON public.products;
CREATE TRIGGER trg_sync_product_cost_price
BEFORE INSERT OR UPDATE ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_product_cost_price();

-- 5. Bidirectional synchronization trigger for public.product_variants
CREATE OR REPLACE FUNCTION public.sync_variant_cost_price()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.cost_price IS NOT NULL AND NEW.purchase_price IS NULL THEN
    NEW.purchase_price := NEW.cost_price;
  ELSIF NEW.purchase_price IS NOT NULL AND NEW.cost_price IS NULL THEN
    NEW.cost_price := NEW.purchase_price;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_variant_cost_price ON public.product_variants;
CREATE TRIGGER trg_sync_variant_cost_price
BEFORE INSERT OR UPDATE ON public.product_variants
FOR EACH ROW EXECUTE FUNCTION public.sync_variant_cost_price();
