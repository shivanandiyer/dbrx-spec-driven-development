# /Workspace/Users/.../test_runner.py

# Run all test files and collect results
test_files = [
    "test_bronze_layer.sql",
    "test_silver_layer.sql", 
    "test_quarantine_logic.sql",
    "test_gold_layer.sql"
]

for test_file in test_files:
    print(f"Running {test_file}...")
    results = spark.sql(open(f"tests/tiny_revenue/{test_file}").read())
    display(results)