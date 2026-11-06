
-- 订单表
CREATE TABLE orders (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20) NOT NULL,
    order_date DATE NOT NULL,
    required_date DATE NOT NULL,
    priority VARCHAR(20) NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    total_amount NUMERIC(14,2) NOT NULL CHECK (total_amount >= 0),
    remark VARCHAR(200),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id),

    CONSTRAINT chk_orders_priority
        CHECK (priority IN ('Normal', 'Urgent')),

    CONSTRAINT chk_orders_status
        CHECK (
            order_status IN (
                'Confirmed',
                'In Production',
                'Completed',
                'Delivered',
                'Cancelled'
            )
        ),

    CONSTRAINT chk_orders_date
        CHECK (required_date > order_date)
);



-- 订单明细表

CREATE TABLE order_items (
    order_item_id VARCHAR(30) PRIMARY KEY,
    order_id VARCHAR(20) NOT NULL,
    product_id VARCHAR(20) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id),

    CONSTRAINT uq_order_product
        UNIQUE (order_id, product_id)
);

/*
用同样的方法导入orders和order_items数据：

\copy orders FROM '/.../raw_data/orders.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

\copy order_items FROM '/.../raw_data/order_items.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

*/

---检查是否成功导入
SELECT * FROM orders
LIMIT 10;
SELECT * FROM order_items
LIMIT 10;