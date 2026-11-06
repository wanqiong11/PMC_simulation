
CREATE TABLE mrp_gross_demand (
    order_id VARCHAR(20) NOT NULL,
    order_item_id VARCHAR(30) NOT NULL,
    required_date DATE NOT NULL,
    product_id VARCHAR(20) NOT NULL,
    order_qty INTEGER NOT NULL,
    material_id VARCHAR(20) NOT NULL,
    quantity_per NUMERIC(12,4) NOT NULL,
    gross_requirement NUMERIC(14,2) NOT NULL,

    CONSTRAINT pk_mrp_gross_demand
        PRIMARY KEY (order_item_id, material_id),

    CONSTRAINT fk_mrp_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),

    CONSTRAINT fk_mrp_order_item
        FOREIGN KEY (order_item_id)
        REFERENCES order_items(order_item_id),

    CONSTRAINT fk_mrp_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id),

    CONSTRAINT fk_mrp_material
        FOREIGN KEY (material_id)
        REFERENCES materials(material_id)
);

INSERT INTO mrp_gross_demand (
    order_id,
    order_item_id,
    required_date,
    product_id,
    order_qty,
    material_id,
    quantity_per,
    gross_requirement
)
SELECT
    o.order_id,
    oi.order_item_id,
    o.required_date,
    oi.product_id,
    oi.quantity AS order_qty,
    b.material_id,
    b.quantity_per,
    oi.quantity * b.quantity_per AS gross_requirement
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN bom b
    ON oi.product_id = b.product_id
WHERE o.order_date <= DATE '2026-09-15'
-- 默认在产的产品已领完全部物料
  AND o.order_status = 'Confirmed';


/*
初步看下物料汇总毛需求

SELECT 
    material_id,
    sum(gross_requirement) as total_gross_demand
FROM mrp_gross_demand
GROUP BY material_id
ORDER BY material_id;
*/