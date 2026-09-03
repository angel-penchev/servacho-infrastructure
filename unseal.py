import urllib.request, json, os, sys

url_health = "http://127.0.0.1:8200/v1/sys/health"
url_unseal = "http://127.0.0.1:8200/v1/sys/unseal"

def is_sealed():
    try:
        urllib.request.urlopen(url_health)
        return False
    except urllib.error.HTTPError as e:
        if e.code == 503 or e.code == 429:
            data = json.loads(e.read().decode())
            return data.get("sealed", False)
        return False
    except Exception as e:
        print(f"Error checking status: {e}")
        return False

if is_sealed():
    print("OpenBao is sealed. Attempting to auto-unseal...")
    keys_str = os.environ.get("UNSEAL_KEYS", "")
    keys = keys_str.replace(",", " ").replace("\n", " ").split()
    if not keys:
        print("Error: OPENBAO_UNSEAL_KEYS secret is not set.")
        sys.exit(1)
    
    for k in keys:
        req = urllib.request.Request(url_unseal, data=json.dumps({"key": k}).encode(), method="PUT")
        try:
            urllib.request.urlopen(req)
        except urllib.error.HTTPError as e:
            pass
            
    if is_sealed():
        print("OpenBao is still sealed. Ensure you provided enough valid keys.")
        sys.exit(1)
    else:
        print("OpenBao successfully unsealed!")
else:
    print("OpenBao is already unsealed or unavailable.")
