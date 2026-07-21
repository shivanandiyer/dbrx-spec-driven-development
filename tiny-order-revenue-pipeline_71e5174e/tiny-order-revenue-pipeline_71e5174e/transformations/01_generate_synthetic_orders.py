# Databricks notebook source
# MAGIC %md
# MAGIC # Synthetic Order Data Generator
# MAGIC 
# MAGIC Generates deterministic synthetic order data for the Tiny Order Revenue PoC.
# MAGIC 
# MAGIC **Features:**
# MAGIC - Fixed random seed (42) for reproducibility
# MAGIC - ~100 valid order records over 30-day period
# MAGIC - Intentional invalid records to test quality and quarantine logic
# MAGIC - Reference date: 2026-06-21 (30 days before execution date)

# COMMAND ----------

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, current_timestamp
from datetime import datetime, timedelta
import random

# Fixed seed for reproducibility
random.seed(42)

# Reference date: 2026-06-21 (30 days before 2026-07-21)
reference_date = datetime(2026, 6, 21)
start_date = reference_date - timedelta(days=29)
end_date = reference_date

print(f"Generating data from {start_date.date()} to {end_date.date()}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Generate Valid Records

# COMMAND ----------

def generate_order_id(i):
    return f"ORD-{i:05d}"

def random_timestamp(start, end):
    delta = end - start
    random_seconds = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=random_seconds)

def generate_valid_orders(count):
    orders = []
    for i in range(1, count + 1):
        order = {
            'order_id': generate_order_id(i),
            'order_timestamp': random_timestamp(start_date, end_date),
            'order_status': random.choice(['COMPLETED', 'COMPLETED', 'COMPLETED', 'CANCELLED', 'PENDING']),
            'sales_channel': random.choice(['ONLINE', 'STORE']),
            'quantity': random.randint(1, 10),
            'unit_price': round(random.uniform(10.0, 500.0), 2),
            'discount_amount': 0.0,
            'source_updated_at': random_timestamp(start_date, end_date)
        }
        # Set discount to valid range (0 to 30% of gross_revenue)
        gross_revenue = order['quantity'] * order['unit_price']
        order['discount_amount'] = round(random.uniform(0, gross_revenue * 0.3), 2)
        orders.append(order)
    return orders

valid_orders = generate_valid_orders(100)
print(f"Generated {len(valid_orders)} valid orders")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Generate Intentional Invalid Records

# COMMAND ----------

invalid_orders = []

# 3 duplicate order IDs with later source_updated_at
for i in [1, 2, 3]:
    dup = valid_orders[i-1].copy()
    dup['source_updated_at'] = dup['source_updated_at'] + timedelta(hours=1)
    dup['quantity'] = random.randint(1, 5)
    invalid_orders.append(dup)

# 2 null or malformed order IDs
invalid_orders.append({
    'order_id': None,
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'ONLINE',
    'quantity': 2,
    'unit_price': 50.00,
    'discount_amount': 5.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

invalid_orders.append({
    'order_id': 'INVALID',
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'STORE',
    'quantity': 1,
    'unit_price': 100.00,
    'discount_amount': 10.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

# 2 invalid order statuses
invalid_orders.append({
    'order_id': generate_order_id(200),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'INVALID_STATUS',
    'sales_channel': 'ONLINE',
    'quantity': 3,
    'unit_price': 75.00,
    'discount_amount': 10.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

invalid_orders.append({
    'order_id': generate_order_id(201),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'SHIPPED',
    'sales_channel': 'STORE',
    'quantity': 2,
    'unit_price': 60.00,
    'discount_amount': 5.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

# 2 zero or negative quantities
invalid_orders.append({
    'order_id': generate_order_id(202),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'ONLINE',
    'quantity': 0,
    'unit_price': 50.00,
    'discount_amount': 0.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

invalid_orders.append({
    'order_id': generate_order_id(203),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'STORE',
    'quantity': -5,
    'unit_price': 100.00,
    'discount_amount': 0.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

# 2 negative unit prices
invalid_orders.append({
    'order_id': generate_order_id(204),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'ONLINE',
    'quantity': 3,
    'unit_price': -50.00,
    'discount_amount': 0.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

invalid_orders.append({
    'order_id': generate_order_id(205),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'STORE',
    'quantity': 2,
    'unit_price': -100.00,
    'discount_amount': 0.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

# 2 discounts greater than gross revenue
invalid_orders.append({
    'order_id': generate_order_id(206),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'ONLINE',
    'quantity': 2,
    'unit_price': 50.00,
    'discount_amount': 150.00,  # Gross revenue is 100
    'source_updated_at': random_timestamp(start_date, end_date)
})

invalid_orders.append({
    'order_id': generate_order_id(207),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'STORE',
    'quantity': 1,
    'unit_price': 100.00,
    'discount_amount': 200.00,  # Gross revenue is 100
    'source_updated_at': random_timestamp(start_date, end_date)
})

# 2 invalid sales channels
invalid_orders.append({
    'order_id': generate_order_id(208),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'PHONE',
    'quantity': 2,
    'unit_price': 75.00,
    'discount_amount': 10.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

invalid_orders.append({
    'order_id': generate_order_id(209),
    'order_timestamp': random_timestamp(start_date, end_date),
    'order_status': 'COMPLETED',
    'sales_channel': 'MOBILE',
    'quantity': 1,
    'unit_price': 50.00,
    'discount_amount': 5.00,
    'source_updated_at': random_timestamp(start_date, end_date)
})

print(f"Generated {len(invalid_orders)} invalid orders")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Create Combined Dataset and Write to Staging Table

# COMMAND ----------

all_orders = valid_orders + invalid_orders
print(f"Total orders: {len(all_orders)}")

# Create DataFrame
df = spark.createDataFrame(all_orders)

# Write to staging table (will be read by bronze layer)
staging_table = "poc_spd.default.synthetic_orders_staging"

df.write.mode("overwrite").saveAsTable(staging_table)

print(f"\nSynthetic data written to {staging_table}")
print(f"Total records: {df.count()}")

# COMMAND ----------

# Show sample records
display(df.orderBy("order_id").limit(10))

# COMMAND ----------

print("\nInvalid record summary:")
print(f"- Duplicate order IDs: 3")
print(f"- Null/malformed order IDs: 2")
print(f"- Invalid order statuses: 2")
print(f"- Zero/negative quantities: 2")
print(f"- Negative unit prices: 2")
print(f"- Excessive discounts: 2")
print(f"- Invalid sales channels: 2")
print(f"\nTotal intentional invalid: {len(invalid_orders)}")