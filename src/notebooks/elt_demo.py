# Databricks notebook source
# MAGIC %md
# MAGIC # ELT Demo Pipeline
# MAGIC This notebook demonstrates a simple Bronze → Silver → Gold data transformation pipeline

# COMMAND ----------

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from datetime import datetime, timedelta
import random

# COMMAND ----------

# Configuration based on environment
# This will be parameterized in the Asset Bundle
dbutils.widgets.text("environment", "dev", "Environment (dev/test/prod)")
environment = dbutils.widgets.get("environment")

# Set catalog based on environment
catalog_map = {
    "dev": "nanba_dev_bronze",
    "test": "nanba_test_silver",
    "prod": "nanba_prod_gold"
}

catalog = catalog_map.get(environment, "nanba_dev_bronze")
spark.sql(f"USE CATALOG {catalog}")
spark.sql("USE SCHEMA default")

print(f"Using catalog: {catalog}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Generate Sample Data (Bronze Layer)

# COMMAND ----------

# Generate sample orders data
def generate_sample_orders(num_records=1000):
    data = []
    statuses = ["pending", "completed", "cancelled", "processing"]
    
    for i in range(num_records):
        order_date = datetime.now() - timedelta(days=random.randint(0, 365))
        data.append({
            "order_id": i + 1,
            "customer_id": random.randint(1, 100),
            "order_date": order_date.date(),
            "amount": round(random.uniform(10.0, 1000.0), 2),
            "status": random.choice(statuses),
            "created_at": order_date,
            "updated_at": order_date + timedelta(hours=random.randint(0, 24))
        })
    
    return spark.createDataFrame(data)

# COMMAND ----------

# Write to Bronze layer
bronze_df = generate_sample_orders(1000)
bronze_df.write.mode("overwrite").saveAsTable("orders_raw")

print(f"✓ Written {bronze_df.count()} records to orders_raw")
bronze_df.show(5)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Data Cleansing and Enrichment (Silver Layer)

# COMMAND ----------

# Read from Bronze
silver_df = spark.table("orders_raw")

# Data cleansing and enrichment
silver_df = silver_df \
    .filter(col("amount") > 0) \
    .filter(col("status").isNotNull()) \
    .withColumn("order_year", year("order_date")) \
    .withColumn("order_month", month("order_date")) \
    .withColumn("order_quarter", quarter("order_date")) \
    .withColumn("days_since_order", datediff(current_date(), col("order_date"))) \
    .withColumn("is_recent_order", when(col("days_since_order") <= 30, True).otherwise(False))

# Add data quality flags
silver_df = silver_df \
    .withColumn("is_high_value", when(col("amount") > 500, True).otherwise(False)) \
    .withColumn("processing_timestamp", current_timestamp())

# Write to Silver layer
silver_df.write.mode("overwrite").saveAsTable("orders_curated")

print(f"✓ Written {silver_df.count()} records to orders_curated")
silver_df.show(5)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Business Aggregations (Gold Layer)

# COMMAND ----------

# Read from Silver
gold_df = spark.table("orders_curated")

# Monthly sales aggregation
monthly_sales = gold_df \
    .groupBy("order_year", "order_month", "status") \
    .agg(
        count("order_id").alias("order_count"),
        sum("amount").alias("total_amount"),
        avg("amount").alias("avg_amount"),
        max("amount").alias("max_amount"),
        min("amount").alias("min_amount")
    ) \
    .withColumn("report_date", current_date()) \
    .withColumn("report_timestamp", current_timestamp())

# Customer metrics
customer_metrics = gold_df \
    .groupBy("customer_id") \
    .agg(
        count("order_id").alias("total_orders"),
        sum("amount").alias("lifetime_value"),
        avg("amount").alias("avg_order_value"),
        max("order_date").alias("last_order_date"),
        min("order_date").alias("first_order_date")
    ) \
    .withColumn("customer_tenure_days", 
                datediff(col("last_order_date"), col("first_order_date")))

# Combine aggregations
final_agg = monthly_sales \
    .select(
        "order_year", 
        "order_month", 
        "status",
        "order_count",
        "total_amount",
        "avg_amount",
        "report_timestamp"
    )

# Write to Gold layer
final_agg.write.mode("overwrite").saveAsTable("orders_agg")

print(f"✓ Written {final_agg.count()} aggregated records to orders_agg")
final_agg.show(10)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Data Quality Checks

# COMMAND ----------

# Perform data quality checks
def run_quality_checks():
    checks = []
    
    # Check 1: Verify no negative amounts in Silver
    negative_amounts = spark.sql("""
        SELECT COUNT(*) as count 
        FROM orders_curated 
        WHERE amount < 0
    """).collect()[0]["count"]
    
    checks.append({
        "check": "No negative amounts",
        "result": "PASS" if negative_amounts == 0 else "FAIL",
        "details": f"Found {negative_amounts} negative amounts"
    })
    
    # Check 2: Verify all orders have valid status
    invalid_status = spark.sql("""
        SELECT COUNT(*) as count 
        FROM orders_curated 
        WHERE status NOT IN ('pending', 'completed', 'cancelled', 'processing')
    """).collect()[0]["count"]
    
    checks.append({
        "check": "Valid order status",
        "result": "PASS" if invalid_status == 0 else "FAIL",
        "details": f"Found {invalid_status} invalid statuses"
    })
    
    # Check 3: Verify aggregation totals match
    source_total = spark.sql("SELECT SUM(amount) as total FROM orders_curated").collect()[0]["total"]
    agg_total = spark.sql("SELECT SUM(total_amount) as total FROM orders_agg").collect()[0]["total"]
    
    checks.append({
        "check": "Aggregation totals match",
        "result": "PASS" if abs(source_total - agg_total) < 0.01 else "FAIL",
        "details": f"Source: {source_total}, Aggregated: {agg_total}"
    })
    
    return spark.createDataFrame(checks)

# COMMAND ----------

# Run quality checks
quality_results = run_quality_checks()
quality_results.show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary

# COMMAND ----------

# Display pipeline summary
print("=" * 50)
print("ELT Pipeline Summary")
print("=" * 50)
print(f"Environment: {environment}")
print(f"Catalog: {catalog}")
print(f"Timestamp: {datetime.now()}")
print("-" * 50)

for table in ["orders_raw", "orders_curated", "orders_agg"]:
    count = spark.sql(f"SELECT COUNT(*) as cnt FROM {table}").collect()[0]["cnt"]
    print(f"{table}: {count} records")

print("=" * 50)
print("✅ ELT Pipeline completed successfully!")