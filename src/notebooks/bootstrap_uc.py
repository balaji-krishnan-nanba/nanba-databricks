# Databricks notebook source
# MAGIC %md
# MAGIC # Unity Catalog Bootstrap
# MAGIC This notebook creates external locations and catalogs in the existing metastore

# COMMAND ----------

from pyspark.sql import SparkSession

# COMMAND ----------

# Configuration
configs = {
    "dev": {
        "catalog": "nanba_dev_bronze",
        "storage_account": "stdlukdev",
        "container": "bronze"
    },
    "test": {
        "catalog": "nanba_test_silver",
        "storage_account": "stdluktest",
        "container": "silver"
    },
    "prod": {
        "catalog": "nanba_prod_gold",
        "storage_account": "stdlukprod",
        "container": "gold"
    }
}

# COMMAND ----------

# Function to create external location
def create_external_location(name, url, credential_name):
    try:
        spark.sql(f"""
            CREATE EXTERNAL LOCATION IF NOT EXISTS {name}
            URL '{url}'
            WITH (STORAGE CREDENTIAL {credential_name})
        """)
        print(f"✓ Created external location: {name}")
    except Exception as e:
        print(f"✗ Error creating external location {name}: {str(e)}")

# COMMAND ----------

# Function to create catalog
def create_catalog(catalog_name, storage_location):
    try:
        spark.sql(f"""
            CREATE CATALOG IF NOT EXISTS {catalog_name}
            MANAGED LOCATION '{storage_location}'
        """)
        print(f"✓ Created catalog: {catalog_name}")
    except Exception as e:
        print(f"✗ Error creating catalog {catalog_name}: {str(e)}")

# COMMAND ----------

# Function to create schema
def create_schema(catalog_name, schema_name):
    try:
        spark.sql(f"""
            CREATE SCHEMA IF NOT EXISTS {catalog_name}.{schema_name}
        """)
        print(f"✓ Created schema: {catalog_name}.{schema_name}")
    except Exception as e:
        print(f"✗ Error creating schema {catalog_name}.{schema_name}: {str(e)}")

# COMMAND ----------

# Function to create sample tables
def create_sample_tables(catalog_name, schema_name):
    tables = ["orders_raw", "orders_curated", "orders_agg"]
    
    for table in tables:
        try:
            spark.sql(f"""
                CREATE TABLE IF NOT EXISTS {catalog_name}.{schema_name}.{table} (
                    order_id BIGINT,
                    customer_id BIGINT,
                    order_date DATE,
                    amount DECIMAL(10,2),
                    status STRING,
                    created_at TIMESTAMP,
                    updated_at TIMESTAMP
                )
                USING DELTA
            """)
            print(f"✓ Created table: {catalog_name}.{schema_name}.{table}")
        except Exception as e:
            print(f"✗ Error creating table {catalog_name}.{schema_name}.{table}: {str(e)}")

# COMMAND ----------

# Main execution
print("Starting Unity Catalog bootstrap...")
print("=" * 50)

# Assuming storage credential already exists (created during workspace setup)
storage_credential_name = "azure_service_principal"

for env, config in configs.items():
    print(f"\nProcessing {env.upper()} environment:")
    print("-" * 30)
    
    # Build storage URLs
    storage_url = f"abfss://{config['container']}@{config['storage_account']}.dfs.core.windows.net/"
    
    # Create external location
    external_location_name = f"ext_loc_{config['catalog']}"
    create_external_location(external_location_name, storage_url, storage_credential_name)
    
    # Create catalog
    create_catalog(config['catalog'], storage_url)
    
    # Create default schema
    create_schema(config['catalog'], "default")
    
    # Create sample tables
    create_sample_tables(config['catalog'], "default")

# COMMAND ----------

# Verify catalogs
print("\n" + "=" * 50)
print("Verifying created catalogs:")
print("-" * 30)

catalogs_df = spark.sql("SHOW CATALOGS")
catalogs_df.show()

# COMMAND ----------

# Grant permissions to all users
for env, config in configs.items():
    catalog_name = config['catalog']
    try:
        spark.sql(f"""
            GRANT USE CATALOG ON CATALOG {catalog_name} TO `account users`
        """)
        spark.sql(f"""
            GRANT USE SCHEMA ON SCHEMA {catalog_name}.default TO `account users`
        """)
        print(f"✓ Granted permissions on {catalog_name}")
    except Exception as e:
        print(f"✗ Error granting permissions on {catalog_name}: {str(e)}")

# COMMAND ----------

print("\n✅ Unity Catalog bootstrap completed successfully!")