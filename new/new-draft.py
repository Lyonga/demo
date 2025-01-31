import boto3
import os
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# -----------------------------------------------------------------------------
# 1) GLOBAL CONSTANTS AND SETUP
# -----------------------------------------------------------------------------

cost_explorer = boto3.client('ce')

MONTHSBACK = 2  # We compare exactly 2 months
today = datetime.now()
first_of_this_month = today.replace(day=1)

start_date = (first_of_this_month - timedelta(days=MONTHSBACK * 30)).replace(day=1)
end_date = first_of_this_month

MONTHLY_START_DATE = start_date.strftime('%Y-%m-%d')
MONTHLY_END_DATE = end_date.strftime('%Y-%m-%d')

print(f"Monthly reporting range: {MONTHLY_START_DATE} to {MONTHLY_END_DATE}")

MONTHLY_COST_DATES = []
temp_date = start_date
while temp_date < end_date:
    MONTHLY_COST_DATES.append(temp_date.strftime('%Y-%m-%d'))
    next_month = (temp_date + timedelta(days=32)).replace(day=1)
    temp_date = next_month

print("MONTHLY_COST_DATES:", MONTHLY_COST_DATES)

accountDict = {
    '384352530920': 'AWS-Workloads-Dev',
    '454229460814': 'AWS-Workloads-QA',
    '235163852221': 'AWS-Workloads-Prod'
}

accountMailDict = {
    '384352530920': 'clyonga@nglic.com',
    '454229460814': 'clyonga@nglic.com',
    '235163852221': 'clyonga@nglic.com'
}

displayListMonthly = [
    '384352530920',
    '454229460814',
    '235163852221',
    'monthTotal'
]

BODY_HTML = '<h2>AWS Monthly Cost Report for Accounts - Summary</h2>'

# # If you want to change the tag filter (e.g. "project=Traverse"), set them here:
# TEAM_TAG_KEY = "Service-Name"
# #TEAM_TAG_VALUE = "modern-data-architecture"
# TEAM_TAG_VALUE = "eloquence"

TEAM_TAG_KEY = "Project"
TEAM_TAG_VALUE = "core" ##"id3-datapipeline"

# -----------------------------------------------------------------------------
# 2) RETRIEVE COST INFO PER ACCOUNT (Summary Table)
# -----------------------------------------------------------------------------

def ce_get_costinfo_per_account(accountDict_input):
    accountCostDict = {}

    for acct_id in accountDict_input:
        print(f"Querying cost data for account: {acct_id}")
        response = cost_explorer.get_cost_and_usage(
            TimePeriod={
                'Start': MONTHLY_START_DATE,
                'End': MONTHLY_END_DATE
            },
            Granularity='MONTHLY',
            Filter={
                'Dimensions': {
                    'Key': 'LINKED_ACCOUNT',
                    'Values': [acct_id]
                }
            },
            Metrics=['UnblendedCost']
        )

        period_cost = 0.0
        for month_data in response['ResultsByTime']:
            cost_val = float(month_data['Total']['UnblendedCost']['Amount'])
            period_cost += cost_val

        print(f"Cost of account {acct_id} for the period {MONTHLY_START_DATE} to {MONTHLY_END_DATE} is: {period_cost}")

        if period_cost > 0:
            accountCostDict[acct_id] = response

    print("Completed ce_get_costinfo_per_account. accountCostDict keys:", list(accountCostDict.keys()))

    print("\n[DEBUG] ce_get_costinfo_per_account() return value:")
    print(accountCostDict)

    return accountCostDict

# -----------------------------------------------------------------------------
# 3) CREATE A MONTHLY-KEYED DICTIONARY OF COSTS
# -----------------------------------------------------------------------------

def process_costchanges_per_month(accountCostDict_input):
    reportCostDict = {}

    for date_str in MONTHLY_COST_DATES:
        reportCostDict[date_str] = {}

    for acct_id, response_data in accountCostDict_input.items():
        for month_data in response_data['ResultsByTime']:
            start_str = month_data['TimePeriod']['Start']
            if start_str not in reportCostDict:
                reportCostDict[start_str] = {}
            reportCostDict[start_str][acct_id] = {
                'Cost': float(month_data['Total']['UnblendedCost']['Amount'])
            }

    for date_str in reportCostDict:
        month_total = 0.0
        for acct_id in reportCostDict[date_str]:
            month_total += reportCostDict[date_str][acct_id]['Cost']
        reportCostDict[date_str]['monthTotal'] = {'Cost': month_total}

    print("Completed process_costchanges_per_month. Keys in reportCostDict:", list(reportCostDict.keys()))

    print("\n[DEBUG] process_costchanges_per_month() return value:")
    print(reportCostDict)

    return reportCostDict

# -----------------------------------------------------------------------------
# 4) FORMAT COSTS FOR "DISPLAY"
# -----------------------------------------------------------------------------

def process_costchanges_for_display(reportCostDict_input):
    displayReportCostDict = {}

    for date_str in reportCostDict_input:
        displayReportCostDict[date_str] = {}
        others_cost = 0.0

        for acct_id, cost_obj in reportCostDict_input[date_str].items():
            if acct_id in displayListMonthly:
                displayReportCostDict[date_str][acct_id] = cost_obj
            else:
                others_cost += cost_obj['Cost']

        displayReportCostDict[date_str]['Others'] = {'Cost': others_cost}

    print("Completed process_costchanges_for_display.")

    print("\n[DEBUG] process_costchanges_for_display() return value:")
    print(displayReportCostDict)

    return displayReportCostDict

# -----------------------------------------------------------------------------
# 5) CALCULATE PERCENT CHANGES MONTH-TO-MONTH
# -----------------------------------------------------------------------------

def process_percentchanges_per_month(reportCostDict_input):
    sorted_months = sorted(reportCostDict_input.keys())
    print("Calculating percent changes across months:", sorted_months)

    for i in range(len(sorted_months)):
        curr_month = sorted_months[i]
        if i == 0:
            for acct_id in reportCostDict_input[curr_month]:
                reportCostDict_input[curr_month][acct_id]['percentDelta'] = None
        else:
            prev_month = sorted_months[i - 1]
            for acct_id, cost_data in reportCostDict_input[curr_month].items():
                curr_cost = cost_data['Cost']
                if acct_id in reportCostDict_input[prev_month]:
                    prev_cost = reportCostDict_input[prev_month][acct_id]['Cost']
                else:
                    prev_cost = 0.0

                if prev_cost == 0 or curr_cost == 0:
                    reportCostDict_input[curr_month][acct_id]['percentDelta'] = None
                else:
                    delta = (curr_cost / prev_cost) - 1
                    reportCostDict_input[curr_month][acct_id]['percentDelta'] = delta

    print("Completed process_percentchanges_per_month.")

    print("\n[DEBUG] process_percentchanges_per_month() return value:")
    print(reportCostDict_input)

    return reportCostDict_input

# -----------------------------------------------------------------------------
# 6) CREATE SUMMARY HTML REPORT
# -----------------------------------------------------------------------------

def create_report_html(emailDisplayDict_input, BODY_HTML):
    print("Generating summary HTML report...")

    def evaluate_change(value):
        if value is None:
            return "<td>&nbsp;</td>"
        elif value < -0.15:
            return f"<td style='text-align:right; color:Navy; font-weight:bold;'>{value:.2%}</td>"
        elif -0.15 <= value < -0.10:
            return f"<td style='text-align:right; color:Blue; font-weight:bold;'>{value:.2%}</td>"
        elif -0.10 <= value < -0.05:
            return f"<td style='text-align:right; color:DodgerBlue; font-weight:bold;'>{value:.2%}</td>"
        elif -0.05 <= value < -0.02:
            return f"<td style='text-align:right; color:DeepSkyBlue; font-weight:bold;'>{value:.2%}</td>"
        elif -0.02 <= value <= 0.02:
            return f"<td style='text-align:right;'>{value:.2%}</td>"
        elif 0.02 < value <= 0.05:
            return f"<td style='text-align:right; color:Orange; font-weight:bold;'>{value:.2%}</td>"
        elif 0.05 < value <= 0.10:
            return f"<td style='text-align:right; color:DarkOrange; font-weight:bold;'>{value:.2%}</td>"
        elif 0.10 < value <= 0.15:
            return f"<td style='text-align:right; color:OrangeRed; font-weight:bold;'>{value:.2%}</td>"
        elif value > 0.15:
            return f"<td style='text-align:right; color:Red; font-weight:bold;'>{value:.2%}</td>"
        else:
            return f"<td style='text-align:right;'>{value:.2%}</td>"

    def row_color(i_row):
        return "<tr style='background-color:WhiteSmoke;'>" if (i_row % 2) == 0 else "<tr>"

    BODY_HTML += "<table border='1' style='border-collapse:collapse; font-family:Arial, sans-serif; font-size:12px;'>"

    # Header row 1
    BODY_HTML += "<tr style='background-color:SteelBlue;'>"
    BODY_HTML += "<td>&nbsp;</td>"
    for acct_id in displayListMonthly:
        if acct_id in accountDict:
            BODY_HTML += f"<td colspan='2' style='text-align:center;'><b>{accountDict[acct_id]}</b></td>"
        elif acct_id == 'monthTotal':
            BODY_HTML += "<td colspan='2' style='text-align:center;'><b>Total</b></td>"
        elif acct_id == 'Others':
            BODY_HTML += "<td colspan='2' style='text-align:center;'><b>Others</b></td>"
    BODY_HTML += "</tr>"

    # Header row 2
    BODY_HTML += "<tr style='background-color:LightSteelBlue;'>"
    BODY_HTML += "<td style='text-align:center;width:80px;'><b>Month</b></td>"
    for acct_id in displayListMonthly:
        if acct_id in accountDict:
            BODY_HTML += f"<td style='text-align:center;width:95px;'>{acct_id}</td><td style='text-align:center;'>&Delta;%</td>"
        elif acct_id == 'monthTotal':
            BODY_HTML += "<td style='text-align:center;width:95px;'>All</td><td style='text-align:center;'>&Delta;%</td>"
        elif acct_id == 'Others':
            BODY_HTML += "<td style='text-align:center;width:95px;'>Others</td><td style='text-align:center;'>&Delta;%</td>"
    BODY_HTML += "</tr>"

    sorted_months = sorted(emailDisplayDict_input.keys())
    i_row = 0
    for month_str in sorted_months:
        BODY_HTML += row_color(i_row)
        BODY_HTML += f"<td style='text-align:center;'>{month_str}</td>"

        for acct_id in displayListMonthly:
            cost_val = emailDisplayDict_input[month_str].get(acct_id, {}).get('Cost', 0.0)
            pct_change = emailDisplayDict_input[month_str].get(acct_id, {}).get('percentDelta', None)

            BODY_HTML += f"<td style='text-align:right; padding:4px;'>$ {cost_val:,.2f}</td>"
            BODY_HTML += evaluate_change(pct_change)

        BODY_HTML += "</tr>"
        i_row += 1

    BODY_HTML += "</table><br>"
    BODY_HTML += f"<div style='font-size:12px; font-style:italic;'>Reporting Window: {MONTHLY_START_DATE} to {MONTHLY_END_DATE}</div>"

    print("\n[DEBUG] create_report_html() HTML output:")
    print(BODY_HTML, "\n")

    return BODY_HTML

# -----------------------------------------------------------------------------
# 7) GET LINKED ACCOUNTS, GET COST DATA, RESTRUCTURE, ETC. (Unchanged)
# -----------------------------------------------------------------------------

def get_linked_accounts(account_list):
    print("get_linked_accounts called.")
    results = []
    token = None

    while True:
        kwargs = {'NextPageToken': token} if token else {}
        linked_accounts = cost_explorer.get_dimension_values(
            TimePeriod={'Start': MONTHLY_START_DATE, 'End': MONTHLY_END_DATE},
            Dimension='LINKED_ACCOUNT',
            **kwargs
        )
        results += linked_accounts['DimensionValues']
        token = linked_accounts.get('NextPageToken')
        if not token:
            break

    active_accounts = [item['Value'] for item in results]
    defined_accounts = [acct for acct in account_list if acct in active_accounts]

    print("Active accounts found:", active_accounts)
    print("Filtered/defined accounts:", defined_accounts)

    print("\n[DEBUG] get_linked_accounts() return value:")
    print(defined_accounts)

    return defined_accounts

def get_cost_data(account_numbers):
    print("get_cost_data called with accounts:", account_numbers)
    results = []
    token = None

    while True:
        kwargs = {'NextPageToken': token} if token else {}
        data = cost_explorer.get_cost_and_usage(
            TimePeriod={'Start': MONTHLY_START_DATE, 'End': MONTHLY_END_DATE},
            Granularity='MONTHLY',
            Metrics=['UnblendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'LINKED_ACCOUNT'},
                {'Type': 'DIMENSION', 'Key': 'SERVICE'}
            ],
            Filter={'Dimensions': {'Key': 'LINKED_ACCOUNT', 'Values': account_numbers}},
            **kwargs
        )
        results += data['ResultsByTime']
        token = data.get('NextPageToken')
        if not token:
            break

    print("Completed get_cost_data.")
    print("\n[DEBUG] get_cost_data() return value:")
    print(results)

    return results

# -----------------------------------------------------------------------------
# 8) NEW: GET TAGGED COST DATA
# -----------------------------------------------------------------------------

def get_tagged_cost_data(account_numbers, tag_key, tag_value):
    """
    Retrieves cost data for the same month range, but filters only resources
    with tag_key=tag_value. Grouped by (LINKED_ACCOUNT, SERVICE).
    """
    print(f"get_tagged_cost_data called for tag {tag_key}={tag_value}")
    results = []
    token = None

    combined_filter = {
        "And": [
            {"Dimensions": {"Key": "LINKED_ACCOUNT", "Values": account_numbers}},
            {"Tags": {"Key": tag_key, "Values": [tag_value]}}
        ]
    }

    while True:
        kwargs = {'NextPageToken': token} if token else {}
        data = cost_explorer.get_cost_and_usage(
            TimePeriod={'Start': MONTHLY_START_DATE, 'End': MONTHLY_END_DATE},
            Granularity='MONTHLY',
            Metrics=['UnblendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'LINKED_ACCOUNT'},
                {'Type': 'DIMENSION', 'Key': 'SERVICE'}
            ],
            Filter=combined_filter,
            **kwargs
        )
        results += data['ResultsByTime']
        token = data.get('NextPageToken')
        if not token:
            break

    print("Completed get_tagged_cost_data.")
    print("\n[DEBUG] get_tagged_cost_data() return value:")
    print(results)

    return results

# -----------------------------------------------------------------------------
# 9) RESTRUCTURE COST DATA FOR PER-SERVICE
# -----------------------------------------------------------------------------

def restructure_cost_data(cost_data_dict, account_numbers):
    print("restructure_cost_data called.")
    display_cost_data_dict = {}

    for acct in account_numbers:
        display_cost_data_dict[acct] = {}

    # Collect all service names
    for time_period in cost_data_dict:
        for group in time_period['Groups']:
            acct_no = group['Keys'][0]
            service_name = group['Keys'][1]
            if acct_no in display_cost_data_dict:
                display_cost_data_dict[acct_no][service_name] = {}

    # Fill in the costs by month
    for time_period in cost_data_dict:
        date = time_period['TimePeriod']['Start']
        for group in time_period['Groups']:
            acct_no = group['Keys'][0]
            service_name = group['Keys'][1]
            amount = float(group['Metrics']['UnblendedCost']['Amount'])
            if acct_no in display_cost_data_dict and service_name in display_cost_data_dict[acct_no]:
                display_cost_data_dict[acct_no][service_name][date] = amount

    # Sort service names
    sorted_dict = {}
    for acct_no, services in display_cost_data_dict.items():
        sorted_services = dict(sorted(services.items()))
        sorted_dict[acct_no] = sorted_services

    print("Completed restructure_cost_data.")
    print("\n[DEBUG] restructure_cost_data() return value:")
    print(sorted_dict)

    return sorted_dict

# -----------------------------------------------------------------------------
# 10) MERGE TEAM + OVERALL, THEN GENERATE A SINGLE 5-COLUMN TABLE
# -----------------------------------------------------------------------------

def merge_team_data(overall_dict, team_dict):
    """
    overall_dict and team_dict have structure:
      { service_name: { "2024-11-01": cost, "2024-12-01": cost } }

    We'll assume exactly 2 months. We'll produce a dictionary:
      { service_name: {
          "overallCurr": <float>,
          "overallDeltaPct": <float or None>,
          "teamDeltaPct": <float or None>,
          "teamDeltaDollar": <float>
        }
      }
    """
    all_services = set(overall_dict.keys()).union(team_dict.keys())
    all_dates = set()
    for svc in overall_dict:
        all_dates.update(overall_dict[svc].keys())
    for svc in team_dict:
        all_dates.update(team_dict[svc].keys())

    sorted_months = sorted(all_dates)
    if len(sorted_months) < 2:
        print("WARNING: Not enough months to compute deltas!")
        return {}

    prev_m = sorted_months[0]
    curr_m = sorted_months[1]

    final_info = {}
    for svc in all_services:
        # overall cost
        prev_overall = overall_dict.get(svc, {}).get(prev_m, 0.0)
        curr_overall = overall_dict.get(svc, {}).get(curr_m, 0.0)

        if prev_overall > 0 and curr_overall > 0:
            overall_delta = (curr_overall / prev_overall) - 1
        else:
            overall_delta = None

        # team cost
        prev_team = team_dict.get(svc, {}).get(prev_m, 0.0)
        curr_team = team_dict.get(svc, {}).get(curr_m, 0.0)

        team_delta_dollar = curr_team - prev_team
        if prev_team > 0 and curr_team > 0:
            team_delta_pct = (curr_team / prev_team) - 1
        else:
            team_delta_pct = None

        final_info[svc] = {
            "overallCurr": curr_overall,
            "overallDeltaPct": overall_delta,
            "teamDeltaPct": team_delta_pct,
            "teamDeltaDollar": team_delta_dollar
        }

    return final_info


def generate_html_table_with_team(final_info, acct_no):
    """
    final_info: { service_name: {
        "overallCurr": float,
        "overallDeltaPct": float or None,
        "teamDeltaPct": float or None,
        "teamDeltaDollar": float
      }
    }

    Creates a 5-column table:
    - Service Name
    - Overall Cost
    - Overall Δ%
    - Team Δ%
    - Team Δ$
    """
    def evaluate_change(value):
        if value is None:
            return ""
        pct = f"{value:.2%}"
        # Basic color coding example
        if value > 0.15:
            return f"<span style='color:Red; font-weight:bold;'>{pct}</span>"
        elif value > 0.05:
            return f"<span style='color:DarkOrange; font-weight:bold;'>{pct}</span>"
        elif value > 0.02:
            return f"<span style='color:Orange; font-weight:bold;'>{pct}</span>"
        elif value >= -0.02:
            return pct
        elif value < -0.15:
            return f"<span style='color:Navy; font-weight:bold;'>{pct}</span>"
        else:
            return f"<span>{pct}</span>"

    html = f"""
    <h3>Team vs. Overall Cost (Account {acct_no})</h3>
    <table border="1" style="border-collapse: collapse; font-family: Arial, sans-serif;">
      <tr style="background-color: SteelBlue; color: white;">
        <th>Service Name</th>
        <th>Overall Cost</th>
        <th>Overall Δ%</th>
        <th>Team Δ%</th>
        <th>Team Δ$</th>
      </tr>
    """

    for svc in sorted(final_info.keys()):
        row = final_info[svc]
        overall_curr = row["overallCurr"]
        overall_delta_pct = row["overallDeltaPct"]
        team_delta_pct = row["teamDeltaPct"]
        team_delta_dollar = row["teamDeltaDollar"]

        html += "<tr>"
        html += f"<td style='padding:4px;'>{svc}</td>"
        html += f"<td style='text-align:right; padding:4px;'>$ {overall_curr:,.2f}</td>"

        # Overall Δ%
        if overall_delta_pct is not None:
            html += f"<td style='text-align:right; padding:4px;'>{evaluate_change(overall_delta_pct)}</td>"
        else:
            html += "<td>&nbsp;</td>"

        # Team Δ%
        if team_delta_pct is not None:
            html += f"<td style='text-align:right; padding:4px;'>{evaluate_change(team_delta_pct)}</td>"
        else:
            html += "<td>&nbsp;</td>"

        # Team Δ$
        html += f"<td style='text-align:right; padding:4px;'>$ {team_delta_dollar:,.2f}</td>"

        html += "</tr>"

    html += "</table>"
    return html

# -----------------------------------------------------------------------------
# 11) SEND REPORT VIA SES (Unchanged)
# -----------------------------------------------------------------------------

def send_report_email(BODY_HTML):
    print("Sending report via SES...")

    SENDER = os.environ.get('SENDER', 'no-reply@example.com')
    RECIPIENT = os.environ.get('RECIPIENT', 'you@example.com')
    AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
    SUBJECT = "AWS Monthly Cost Report for Selected Accounts"
    BODY_TEXT = "AWS Cost Report (HTML Email)."

    print(f"SENDER={SENDER}, RECIPIENT={RECIPIENT}, REGION={AWS_REGION}")

    client = boto3.client('ses', region_name=AWS_REGION)

    try:
        response = client.send_email(
            Destination={'ToAddresses': [RECIPIENT]},
            Message={
                'Body': {
                    'Html': {'Charset': "UTF-8", 'Data': BODY_HTML},
                    'Text': {'Charset': "UTF-8", 'Data': BODY_TEXT},
                },
                'Subject': {'Charset': "UTF-8", 'Data': SUBJECT},
            },
            Source=SENDER
        )
        print("Email sent! Message ID:", response['MessageId'])
    except ClientError as e:
        print("SES send_email Error:", e.response['Error']['Message'])

# -----------------------------------------------------------------------------
# 12) LAMBDA HANDLER
# -----------------------------------------------------------------------------

def lambda_handler(event=None, context=None):
    print("=== Starting Lambda Execution ===")

    # 1) Summarize monthly cost per account (the top summary table)
    mainCostDict = ce_get_costinfo_per_account(accountDict)
    mainMonthlyDict = process_costchanges_per_month(mainCostDict)
    mainDisplayDict = process_costchanges_for_display(mainMonthlyDict)
    finalDisplayDict = process_percentchanges_per_month(mainDisplayDict)

    # 2) Build the summary HTML (the table that looks like your screenshot)
    summary_html = create_report_html(finalDisplayDict, BODY_HTML)

    # 3) Gather the "per-service" overall cost (like your existing breakdown)
    account_numbers = list(accountDict.keys())
    cost_data_Dict = get_cost_data(account_numbers)
    display_cost_data_Dict = restructure_cost_data(cost_data_Dict, account_numbers)

    # 4) Also gather the "per-service" cost for the team (tag filter)
    team_data_Dict = get_tagged_cost_data(account_numbers, TEAM_TAG_KEY, TEAM_TAG_VALUE)
    display_team_data_Dict = restructure_cost_data(team_data_Dict, account_numbers)

    # 5) For each account, merge the overall + team cost into a single dict,
    #    then generate a combined HTML table with 5 columns:
    #      (Service, Overall Cost, Overall Δ%, Team Δ%, Team Δ$)
    breakdown_html = ""
    for acct_id in display_cost_data_Dict:
        overall_dict = display_cost_data_Dict[acct_id]   # {service: {month: cost}}
        team_dict = display_team_data_Dict.get(acct_id, {})
        final_info = merge_team_data(overall_dict, team_dict)

        # Create the table for this account
        table_html = generate_html_table_with_team(final_info, acct_id)
        breakdown_html += table_html
        breakdown_html += "<br><br>"

    # 6) Combine summary + new breakdown
    combined_html = summary_html + '<br><br>' + breakdown_html
    print("=== Final Combined HTML ===\n", combined_html[:1000], "... (truncated)\n")

    # 7) Send the email via SES
    send_report_email(combined_html)

    print("=== Completed Lambda Execution ===")
    return {
        'statusCode': 200,
        'body': 'Monthly Cost Report Sent!'
    }
