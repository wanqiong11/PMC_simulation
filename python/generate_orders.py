import random
from datetime import date, timedelta
from pathlib import Path
from collections import defaultdict

import pandas as pd



# ====================
# 1. 基础配置
# ====================


RANDOM_SEED = 20260915
random.seed(RANDOM_SEED)

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "raw_data"

CUSTOMERS_FILE = DATA_DIR / "customers.csv"
PRODUCTS_FILE = DATA_DIR / "products.csv"

ORDERS_FILE = DATA_DIR / "orders.csv"
ORDER_ITEMS_FILE = DATA_DIR / "order_items.csv"

# PMC 计划日期
PLANNING_DATE = date(2026, 9, 15)

# 只生成计划日期之前已经产生的订单
ORDER_START_DATE = date(2026, 8, 20)
ORDER_END_DATE = PLANNING_DATE

ORDER_COUNT = 60


# ====================
# 2. 读取基础数据
# ====================

customers = pd.read_csv(CUSTOMERS_FILE)
products = pd.read_csv(PRODUCTS_FILE)



# ====================
# 3. 产品需求权重
# ====================


product_weights = {
    "P001": 20,
    "P002": 10,
    "P003": 14,
    "P004": 8,
    "P005": 18,
    "P006": 10
}



# ====================
# 4. 产品订单数量范围
# ====================

quantity_range = {
    "P001": (20, 80),
    "P002": (15, 60),
    "P003": (20, 70),
    "P004": (15, 50),
    "P005": (30, 100),
    "P006": (20, 70)
}


# ====================
# 5. 辅助函数
# ====================


def random_date(start_date, end_date):
    '''在两个日期之间随机生成一个日期'''
    days = (end_date - start_date).days
    return start_date + timedelta(days=random.randint(0, days))

def generate_required_date(order_date, priority):
    '''
    根据订单日期和优先级生成要求交期。

    设计思路：
    - 普通订单：15~35天
    - 紧急订单：8~15天
    - 少部分订单延长到更晚，形成10月底订单
    '''

    if priority == "Urgent":
        lead_days = random.randint(8, 15)

    else:
        # 约 5% 的订单设置为较长交期
        long_lead_order = random.random() < 0.05

        if long_lead_order:
            lead_days = random.randint(35, 50)
        else:
            lead_days = random.randint(15, 35)

    return order_date + timedelta(days=lead_days)


def generate_order_status(order_date, required_date):
    '''根据订单生命周期模拟订单当前状态'''

    # 3%的概率订单取消
    if random.random() < 0.03:
        return "Cancelled"

    # 交期在10月的订单仅确认
    if required_date > PLANNING_DATE + timedelta(days=15):
        return "Confirmed"
    
    # 根据下单时间模拟生产进度
    order_age = (PLANNING_DATE - order_date).days

    if order_age <= 5:
        return "Confirmed"


    if order_age <= 15:
        return random.choices(
            ["Confirmed", "In Production", "Completed"],
            weights=[40, 50, 10],
            k=1
        )[0]
    
    if order_age <= 20:
        return random.choices(
            ["In Production", "Completed", "Delivered"],
            weights=[65, 15, 20],
            k=1
        )[0]


    return random.choices(
        ["In Production", "Completed", "Delivered"],
        weights=[10, 6, 84],
        k=1
    )[0]



# ====================
# 6. 生成订单
# ====================

orders = []
order_items = []

date_counter = defaultdict(int)

for _ in range(ORDER_COUNT):

    

    # 客户
    customer_id = random.choice(customers["customer_id"].tolist())

    
    # 下单日期
    order_date = random_date(
        ORDER_START_DATE,
        ORDER_END_DATE
    )

    #订单号
    date_str = order_date.strftime('%Y%m%d')
    date_counter[date_str] += 1
    seq = date_counter[date_str]
    order_id = f"O{date_str}{seq:03d}"

    # 优先级
    priority = random.choices(
        ["Normal", "Urgent"],
        weights=[85, 15],
        k=1
    )[0]

    #订单备注
    if priority == "Urgent":
        remark = "加急"
    else: 
        remark = None

    # 要求交期
    required_date = generate_required_date(
        order_date,
        priority
    )


    # 订单状态
    order_status = generate_order_status(
        order_date,
        required_date
    )

    
    # 订单产品数量
    product_count = random.choices(
        [1, 2, 3],
        weights=[58, 30, 12],
        k=1
    )[0]

    
    # 按产品权重随机选择
    selected_products = random.choices(
        list(product_weights.keys()),
        weights=list(product_weights.values()),
        k=product_count
    )

    selected_products = list(dict.fromkeys(selected_products))

    ''' 如果去重后数量不足，补充未选择产品 '''
    available_products = [
        p for p in product_weights
        if p not in selected_products
    ]

    while len(selected_products) < product_count:
        p = random.choice(available_products)
        selected_products.append(p)
        available_products.remove(p)

    

    # ---生成订单明细---
    
    total_amount = 0

    for item_index, product_id in enumerate(selected_products, start=1):

        product_row = products[
            products["product_id"] == product_id
        ].iloc[0]

        unit_price = float(product_row["unit_price"])

        min_qty, max_qty = quantity_range[product_id]

        quantity = random.randint(
            min_qty,
            max_qty
        )

        amount = quantity * unit_price

        total_amount += amount

        order_item_id = (
            f"{order_id}-{item_index:02d}"
        )

        order_items.append({
            "order_item_id": order_item_id,
            "order_id": order_id,
            "product_id": product_id,
            "quantity": quantity,
            "unit_price": unit_price,
            "amount": amount
        })

    
    # ---订单主表---

    orders.append({
        "order_id": order_id,
        "customer_id": customer_id,
        "order_date": order_date,
        "required_date": required_date,
        "priority": priority,
        "order_status": order_status,
        "total_amount": total_amount,
        "remark": remark
    })


# ====================
# 7. 转换为 DataFrame
# ====================

orders_df = pd.DataFrame(orders)
order_items_df = pd.DataFrame(order_items)


# ====================
# 8. 数据类型与格式
# ====================

orders_df["order_date"] = pd.to_datetime(
    orders_df["order_date"]
).dt.strftime("%Y-%m-%d")

orders_df["required_date"] = pd.to_datetime(
    orders_df["required_date"]
).dt.strftime("%Y-%m-%d")

order_items_df["unit_price"] = order_items_df[
    "unit_price"
].round(2)

order_items_df["amount"] = order_items_df[
    "amount"
].round(2)

orders_df["total_amount"] = orders_df[
    "total_amount"
].round(2)


# ====================
# 9. 排序
# ====================

orders_df = orders_df.sort_values(
    ["order_date","order_id"]
)

order_items_df = order_items_df.sort_values(
    ["order_id","order_item_id"]
)

# ====================
# 10. 输出 CSV
# ====================

orders_df.to_csv(
    ORDERS_FILE,
    index=False,
    encoding="utf-8-sig"
)

order_items_df.to_csv(
    ORDER_ITEMS_FILE,
    index=False,
    encoding="utf-8-sig"
)

# =========================================================
# 10. 输出检查结果
# =========================================================

print("---订单数据生成完成---")

print(f"订单数量：{len(orders_df)}")
print(f"订单明细数量：{len(order_items_df)}")

print("\n产品需求量：")
print(
    order_items_df
    .groupby("product_id")["quantity"]
    .sum()
    .sort_index()
)

print("\n订单日期范围：")
print(
    orders_df["order_date"].min(),
    "~",
    orders_df["order_date"].max()
)

print("\n要求交期范围：")
print(
    orders_df["required_date"].min(),
    "~",
    orders_df["required_date"].max()
)

print("\n订单状态分布：")
print(
    orders_df["order_status"]
    .value_counts()
)


print("\nCSV 输出：")
print(ORDERS_FILE)
print(ORDER_ITEMS_FILE)

'''
输出结果：

订单数量：60
订单明细数量：98

产品需求量：
product_id
P001    1316
P002     584
P003     574
P004     303
P005    1546
P006     798
Name: quantity, dtype: int64

订单日期范围：
2026-08-20 ~ 2026-09-15

要求交期范围：
2026-09-10 ~ 2026-10-23

订单状态分布：
order_status
Confirmed        33
In Production    13
Delivered        11
Completed         2
Cancelled         1
Name: count, dtype: int64

CSV 输出：
/.../raw_data/orders.csv
/.../raw_data/order_items.csv

'''