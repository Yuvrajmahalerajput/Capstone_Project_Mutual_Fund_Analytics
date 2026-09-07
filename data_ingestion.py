import os
import pandas as pd

def inspect_datasets(data_dir="data/raw"):
    csv_files = [f for f in os.listdir(data_dir) if f.endswith('.csv') and f != 'hdfc_top_100_raw.csv']
    if not csv_files:
        print(f"⚠️ No CSV files found in {data_dir}.")
        return
    print(f"🔍 Found {len(csv_files)} datasets. Starting inspection...\n")
    for file in csv_files:
        file_path = os.path.join(data_dir, file)
        print("="*60)
        print(f"📊 DATASET: {file}")
        print("="*60)
        try:
            df = pd.read_csv(file_path)
            print(f"🔹 Shape: {df.shape} rows, {df.shape} columns\n")
            print("🔹 Data Types:")
            print(df.dtypes)
            print("\n🔹 First 3 Rows:")
            print(df.head(3))
            print("\n⚠️ Potential Anomalies:")
            missing = df.isnull().sum()
            dupes = df.duplicated().sum()
            has_anomalies = False
            if missing.sum() > 0:
                print(" - Missing values detected:")
                print(missing[missing > 0])
                has_anomalies = True
            if dupes > 0:
                print(f" - Duplicate rows found: {dupes}")
                has_anomalies = True
            if not has_anomalies:
                print(" - No basic structural anomalies detected.")
            print("\n")
        except Exception as e:
            print(f"❌ Error reading {file}: {e}\n")

if __name__ == "__main__":
    inspect_datasets()
