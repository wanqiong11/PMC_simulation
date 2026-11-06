-- 创建和生成采购在途订单

CREATE TABLE purchase_orders (
    po_id VARCHAR(20) PRIMARY KEY,
    material_id VARCHAR(20) NOT NULL,
    supplier_id VARCHAR(20) NOT NULL,
    po_date DATE NOT NULL,
    expected_date DATE NOT NULL,
    ordered_qty NUMERIC(14,2) NOT NULL CHECK (ordered_qty > 0),
    received_qty NUMERIC(14,2) NOT NULL DEFAULT 0
        CHECK (received_qty >= 0),
    po_status VARCHAR(20) NOT NULL,
    unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),

    CONSTRAINT fk_po_material
        FOREIGN KEY (material_id)
        REFERENCES materials(material_id),

    CONSTRAINT fk_po_supplier
        FOREIGN KEY (supplier_id)
        REFERENCES suppliers(supplier_id),

    CONSTRAINT chk_po_status
        CHECK (
            po_status IN (
                'In Transit',
                'Received'
            )
        ),

    CONSTRAINT chk_received_qty
        CHECK (received_qty <= ordered_qty),

    CONSTRAINT chk_po_date
        CHECK (expected_date > po_date)
);

/*
用同样的方法导入purchase_orders数据：

\copy purchase_orders FROM '/.../raw_data/purchase_orders.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

*/

---检查是否成功导入
SELECT * FROM purchase_orders;

