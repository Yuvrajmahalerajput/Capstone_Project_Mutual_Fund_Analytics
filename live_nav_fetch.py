import os
import requests
import pandas as pd

def fetch_and_save_hdfc():
    url = "https://mfapi.in"
    print("🌐 Fetching HDFC Top 100 Direct (125497)...")
    try:
        res = requests.get(url, timeout=5)
        if res.status_code == 200:
            data = res.json()
            meta = data.get('meta', {})
            nav_list = data.get('data', [])
            df = pd.DataFrame(nav_list)
            df['scheme_code'] = meta.get('scheme_code')
            df['scheme_name'] = meta.get('scheme_name')
            os.makedirs("data/raw", exist_ok=True)
            df.to_csv("data/raw/hdfc_top_100_raw.csv", index=False)
            print(f"✅ Saved HDFC NAV data to data/raw/hdfc_top_100_raw.csv ({df.shape} rows)\n")
        else:
            print("❌ Failed to fetch HDFC data. Server returned status code:", res.status_code)
    except Exception as e:
        print("💡 Internet connection offline. Skipping live fetch download, proceeding to structural validation...\n")

def fetch_key_schemes():
    schemes = {"119551": "SBI Bluechip", "120503": "ICICI Bluechip", "118632": "Nippon Large Cap", "119092": "Axis Bluechip", "120841": "Kotak Bluechip"}
    print("🌐 Fetching 5 Key Schemes...")
    try:
        for code, name in schemes.items():
            res = requests.get(f"https://mfapi.in{code}", timeout=2)
            if res.status_code == 200:
                data = res.json()
                latest = data.get('data', [{}])[0].get('nav', 'N/A')
                print(f"📈 {name} ({code}) -> Latest NAV: Rs.{latest}")
    except Exception:
        print("💡 Network offline. Key scheme live stats skipped.\n")

def explore_and_validate():
    print("🧐 --- FUND MASTER EXPLORATION & VALIDATION ---")
    master_path = "data/raw/fund_master.csv"
    history_path = "data/raw/nav_history.csv"
    
    if os.path.exists(master_path) and os.path.exists(history_path):
        m = pd.read_csv(master_path)
        h = pd.read_csv(history_path)
        
        # Explore fields
        for col in ['fund_house', 'category', 'sub_category', 'risk_grade']:
            if col in m.columns:
                print(f"🔹 Unique {col.replace('_', ' ').title()}: {m[col].nunique()}")
                
        # Validate AMFI codes
        if 'amfi_code' in m.columns and 'amfi_code' in h.columns:
            m_codes = set(m['amfi_code'].unique())
            h_codes = set(h['amfi_code'].unique())
            missing = m_codes - h_codes
            if not missing:
                print("✅ VALIDATION SUCCESS: Every code in fund_master exists in nav_history.")
            else:
                print(f"❌ VALIDATION FAILURE: {len(missing)} codes in fund_master do not exist in nav_history.")
        else:
            print("❌ Validation Columns Not Found. Check if columns match 'amfi_code'.")
    else:
        print("💡 Missing dependency data files inside data/raw/ directory.")

if __name__ == "__main__":
    fetch_and_save_hdfc()
    fetch_key_schemes()
    explore_and_validate()
