
CREATE TABLE material_shortage_events (
    material_id VARCHAR(20) NOT NULL,
    shortage_start_date DATE NOT NULL,
    shortage_end_date DATE NOT NULL,
    lowest_inventory NUMERIC(14,2) NOT NULL,
    safety_stock NUMERIC(14,2) NOT NULL,
    shortage_qty NUMERIC(14,2) NOT NULL,

    po_id VARCHAR(20),
    po_available_date DATE,
    po_available_qty NUMERIC(14,2),

    inventory_after_po NUMERIC(14,2),

    shortage_status VARCHAR(30) NOT NULL,

    CONSTRAINT fk_shortage_material
        FOREIGN KEY (material_id)
        REFERENCES materials(material_id),

    CONSTRAINT fk_shortage_po
        FOREIGN KEY (po_id)
        REFERENCES purchase_orders(po_id),

    CONSTRAINT chk_shortage_status
        CHECK (
            shortage_status IN (
                'Still Shortage',
                'Recovered',
                'Need Purchase'
            )
        )
);

INSERT INTO material_shortage_events (
    material_id,
    shortage_start_date,
    shortage_end_date,
    lowest_inventory,
    safety_stock,
    shortage_qty,
    po_id,
    po_available_date,
    po_available_qty,
    inventory_after_po,
    shortage_status
)

WITH inventory_base AS (

    SELECT
        material_id,
        material_need_date,
        projected_inventory,
        safety_stock,

        LAG(projected_inventory)
        OVER (
            PARTITION BY material_id
            ORDER BY material_need_date
        ) AS prev_inventory

    FROM mrp_net_requirement

),

--- 库存上涨，认为发生了一次补货，用于划分不同的缺料阶段
inventory_stage AS (
   
    SELECT
        *,
        CASE
            WHEN prev_inventory IS NOT NULL
             AND projected_inventory > prev_inventory
            THEN 1
            ELSE 0
        END AS replenish_flag

    FROM inventory_base

),

stage_group AS (

    SELECT
        *,
        SUM(replenish_flag)
        OVER (
            PARTITION BY material_id
            ORDER BY material_need_date
        ) AS stage_id

    FROM inventory_stage

),

--- 只保留低于安全库存的日期，形成缺料区间

shortage_data AS (

    SELECT *
    FROM stage_group
    WHERE projected_inventory < safety_stock

),

shortage_groups AS (

    SELECT
        material_id,
        stage_id,

        MIN(material_need_date) AS shortage_start_date,
        MAX(material_need_date) AS shortage_end_date,
        MIN(projected_inventory) AS lowest_inventory,
        MAX(safety_stock) AS safety_stock
    FROM shortage_data

    GROUP BY
        material_id,
        stage_id

),

/*
计算下一段缺料开始时间
用于确定 PO 应该属于哪一个缺料区间
*/

shortage_intervals AS (

    SELECT
        *,
        
        LEAD(shortage_start_date)
        OVER (
            PARTITION BY material_id
            ORDER BY shortage_start_date
        ) AS next_shortage_start_date

    FROM shortage_groups

),

/*
缺料区间对应的 PO

PO 到货日期：
    > 当前 shortage_end_date

同时：
    < 下一段 shortage_end_date

这样可以避免一个 PO 被错误分配到多个缺料事件。
*/
po_data AS (

    SELECT
        s.material_id,
        s.stage_id,
        s.shortage_start_date,
        s.shortage_end_date,
        s.lowest_inventory,
        s.safety_stock,

        po.po_id,

        po.expected_date + m.inspection_days
            AS po_available_date,

        po.ordered_qty - po.received_qty
            AS po_available_qty

    FROM shortage_intervals s

    JOIN purchase_orders po
        ON s.material_id = po.material_id

    JOIN materials m
        ON po.material_id = m.material_id

    WHERE po.po_status = 'In Transit'

      /*
      PO 必须在该缺料区间结束之后到货
      */
      AND po.expected_date + m.inspection_days
            > s.shortage_end_date

      /*
      如果后面还有一个缺料区间，
      PO 到货日期必须落在当前区间和下一缺料区间之间

      最后一段缺料则不设上限
      */
      AND (
          s.next_shortage_start_date IS NULL
          OR po.expected_date + m.inspection_days
                <= s.next_shortage_start_date
      )

),

/*
计算每个缺料区间内，
PO 按到货日期累计后的库存
*/
po_inventory AS (

    SELECT
        p.*,

        p.lowest_inventory

        + SUM(p.po_available_qty)
          OVER (
              PARTITION BY p.material_id, p.stage_id
              ORDER BY p.po_available_date, p.po_id
          )
        AS inventory_after_po

    FROM po_data p

),

/*
找到每个缺料区间中，
第一批能够恢复到安全库存的 PO
*/
recovery_po AS (

    SELECT
        material_id,
        stage_id,

        MIN(po_available_date) AS recovery_date

    FROM po_inventory

    WHERE inventory_after_po >= safety_stock

    GROUP BY
        material_id,
        stage_id

),

/*
最终 PO 结果

如果某个 PO 是第一批恢复安全库存的 PO：
    Recovered

在它之前的 PO：
    Still Shortage

如果整个缺料区间没有任何 PO：
    Need Purchase
*/
final_po AS (

    SELECT
        p.*,
        r.recovery_date

    FROM po_inventory p

    LEFT JOIN recovery_po r
        ON p.material_id = r.material_id
       AND p.stage_id = r.stage_id

),

/*
没有 PO 的缺料事件
*/
no_po_shortage AS (

    SELECT
        s.material_id,
        s.stage_id,
        s.shortage_start_date,
        s.shortage_end_date,
        s.lowest_inventory,
        s.safety_stock,

        NULL::VARCHAR(20) AS po_id,
        NULL::DATE AS po_available_date,
        NULL::NUMERIC(14,2) AS po_available_qty,
        NULL::NUMERIC(14,2) AS inventory_after_po,

        'Need Purchase' AS shortage_status

    FROM shortage_intervals s

    LEFT JOIN po_data p
        ON s.material_id = p.material_id
       AND s.stage_id = p.stage_id

    WHERE p.material_id IS NULL

),

/*
有 PO 的缺料事件
*/
po_result AS (

    SELECT
        material_id,
        stage_id,
        shortage_start_date,
        shortage_end_date,
        lowest_inventory,
        safety_stock,

        po_id,
        po_available_date,
        po_available_qty,
        inventory_after_po,

        CASE
            WHEN recovery_date IS NOT NULL
             AND po_available_date = recovery_date
            THEN 'Recovered'

            ELSE 'Still Shortage'

        END AS shortage_status

    FROM final_po

)

SELECT
    material_id,
    shortage_start_date,
    shortage_end_date,
    lowest_inventory,
    safety_stock,

    safety_stock - lowest_inventory AS shortage_qty,

    po_id,
    po_available_date,
    po_available_qty,
    inventory_after_po,

    shortage_status

FROM po_result

UNION ALL

SELECT
    material_id,
    shortage_start_date,
    shortage_end_date,
    lowest_inventory,
    safety_stock,

    safety_stock - lowest_inventory AS shortage_qty,

    po_id,
    po_available_date,
    po_available_qty,
    inventory_after_po,

    shortage_status

FROM no_po_shortage

ORDER BY
    material_id,
    shortage_start_date,
    po_available_date;