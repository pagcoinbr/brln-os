# This script sends information about your Lightning node's channels and capacity to sparkseer.space
# and receives SATs as payment.

import subprocess
import requests
from datetime import datetime, timedelta

# Replace with your API_KEY - you can get it on https://sparkseer.space/account
API_KEY = "Sua_chave_API_aqui"
PAYMENTS_API_URL = "https://api.sparkseer.space/v1/sats4stats/payouts"
PROBES_API_URL = "https://api.sparkseer.space/v1/sats4stats/probes"

def get_last_payment_time():
    headers = {"api-key": API_KEY}
    response = requests.get(PAYMENTS_API_URL, headers=headers)
    try:
        payouts = response.json().get("payouts", [])
        last_three_payouts = payouts[-3:]
        print("Last 3 payouts:")
        for payout in last_three_payouts:
            date_submitted = payout.get("date_submitted")
            amount = payout["details"][0].get("amount")
            hash_value = payout["details"][0].get("hash")
            print(f"Date: {date_submitted}, Amount: {amount}, Hash: {hash_value}")

        if payouts:
            latest_payout_time_str = payouts[-1].get("date_submitted")
            latest_payout_time = datetime.strptime(latest_payout_time_str, "%Y-%m-%d %H:%M:%S")
            return latest_payout_time
        else:
            # Assume it's the first time
            return datetime.now() - timedelta(hours=24)
    except ValueError:
        print("Error: Unable to parse payouts API response as JSON")
        return None

def send_node_info():
    last_payment_time = get_last_payment_time()
    if last_payment_time:
        time_difference = datetime.now() - (last_payment_time - timedelta(hours=3))

        if time_difference >= timedelta(hours=24):
            current_datetime = datetime.now().strftime("%d-%m-%Y %H:%M:%S")
            print(f"Current date and time: {current_datetime}")

            try:
                # Execute lncli querymc
                command_output = subprocess.run(
                    ["lncli", "querymc"],
                    capture_output=True,
                    text=True,
                    check=True
                )
                if command_output.stdout.strip():
                    headers = {
                        "Content-Type": "application/json",
                        "api-key": API_KEY
                    }
                    response = requests.post(PROBES_API_URL, headers=headers, data=command_output.stdout)

                    try:
                        response_json = response.json()
                        if "error" in response_json:
                            error_value = response_json.get("error")
                            print(f"Error value: {error_value}")
                        elif "receipt" in response_json:
                            receipt = response_json.get("receipt")
                            settlement_time = receipt.get("settlement_time")
                            amount = receipt.get("amount")
                            hash_value = receipt.get("hash")
                            print(f"Your bid was sent successfully at {settlement_time}. "
                                  f"You received {amount} sats, and the hash is {hash_value}")
                    except ValueError:
                        print("Error: Unable to parse API response as JSON")
                else:
                    print("Error: Command output is empty. Please check lncli or the querymc command.")
            except subprocess.CalledProcessError as e:
                print(f"Error executing lncli command: {e}")
        else:
            print("Less than 24 hours since the last payment. No action needed.")
    else:
        print("Error: Unable to retrieve last payment time.")

if __name__ == "__main__":
    send_node_info()
