import boto3
import os
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# -----------------------------------------------------------------------------
# 1) GLOBAL CONSTANTS AND SETUP
# -----------------------------------------------------------------------------

cost_explorer = boto3.client('ce')

MONTHSBACK = 9
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

# -----------------------------------------------------------------------------
# 2) RETRIEVE COST INFO PER ACCOUNT
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

    # **Print the result** just before returning
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

    # Print before returning
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

    # Print before returning
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

    # Print before returning
    print("\n[DEBUG] process_percentchanges_per_month() return value:")
    print(reportCostDict_input)

    return reportCostDict_input

# -----------------------------------------------------------------------------
# 6) CREATE HTML REPORT
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

    # Print before returning
    print("\n[DEBUG] create_report_html() HTML output (truncated to 500 chars):")
    print(BODY_HTML[:500], "...\n")

    return BODY_HTML

# -----------------------------------------------------------------------------
# 7) OPTIONAL: GET LINKED ACCOUNTS (PER-SERVICE)
# -----------------------------------------------------------------------------

def get_linked_accounts(account_list):
    print("get_linked_accounts called.")
    results = []
    token = None

    while True:
        if token:
            kwargs = {'NextPageToken': token}
        else:
            kwargs = {}

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

    # Print before returning
    print("\n[DEBUG] get_linked_accounts() return value:")
    print(defined_accounts)

    return defined_accounts

# -----------------------------------------------------------------------------
# 8) GET COST DATA GROUPED BY ACCOUNT & SERVICE
# -----------------------------------------------------------------------------

def get_cost_data(account_numbers):
    print("get_cost_data called with accounts:", account_numbers)
    results = []
    token = None

    while True:
        if token:
            kwargs = {'NextPageToken': token}
        else:
            kwargs = {}

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

    # Print before returning
    print("\n[DEBUG] get_cost_data() return value:")
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

    # Print before returning
    print("\n[DEBUG] restructure_cost_data() return value:")
    print(sorted_dict)

    return sorted_dict

# -----------------------------------------------------------------------------
# 10) GENERATE HTML TABLE FOR PER-SERVICE BREAKDOWN
# -----------------------------------------------------------------------------

def generate_html_table(cost_data_dict, display_cost_data_dict):
    print("generate_html_table called.")

    sorted_months = sorted([rbt['TimePeriod']['Start'] for rbt in cost_data_dict])
    num_months = len(sorted_months)
    columns = (num_months * 1) + (num_months - 1)

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

    emailHTML = "<h2>AWS Monthly Cost Report - Per Service Breakdown</h2>"
    emailHTML += f'<table border="1" style="border-collapse:collapse; font-family:Arial,sans-serif;">'

    for acct_no, services in display_cost_data_dict.items():
        acct_name = accountDict.get(acct_no, acct_no)
        # Header for this account
        emailHTML += f'<tr style="background-color:SteelBlue;"><td colspan="{columns}" style="text-align:center; font-weight:bold;">'
        emailHTML += f'{acct_name} ({acct_no})</td></tr>'

        # Subheader row
        emailHTML += '<tr style="background-color:LightSteelBlue;">'
        emailHTML += '<td style="text-align:center; font-weight:bold;">Service Name</td>'
        for idx, m in enumerate(sorted_months):
            if idx > 0:
                emailHTML += '<td style="text-align:center;">Δ%</td>'
            emailHTML += f'<td style="text-align:center; font-weight:bold;">{m}</td>'
        emailHTML += '</tr>'

        i_row = 0
        for svc, monthly_data in services.items():
            row_html = row_color(i_row)
            row_html += f'<td style="text-align:left;">{svc}</td>'

            prev_cost = None
            for idx, m in enumerate(sorted_months):
                curr_cost = monthly_data.get(m, 0.0)
                if idx > 0:
                    if prev_cost and prev_cost != 0 and curr_cost != 0:
                        pct_change = (curr_cost / prev_cost) - 1
                        row_html += evaluate_change(pct_change)
                    else:
                        row_html += '<td>&nbsp;</td>'
                row_html += f'<td style="text-align:right; padding:4px;">$ {curr_cost:,.2f}</td>'
                prev_cost = curr_cost

            row_html += '</tr>'
            emailHTML += row_html
            i_row += 1

    emailHTML += '</table>'
    print("Completed generate_html_table.")

    # Print before returning
    print("\n[DEBUG] generate_html_table() HTML output (truncated to 500 chars):")
    print(emailHTML[:500], "...\n")

    return emailHTML

# -----------------------------------------------------------------------------
# 11) SEND REPORT VIA SES
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

    # 1) Summarize monthly cost per account
    mainCostDict = ce_get_costinfo_per_account(accountDict)
    print("mainCostDict:", mainCostDict)

    # 2) Re-sort data by month
    mainMonthlyDict = process_costchanges_per_month(mainCostDict)
    print("mainMonthlyDict:", mainMonthlyDict)

    # 3) Combine 'Others' + 'monthTotal'
    mainDisplayDict = process_costchanges_for_display(mainMonthlyDict)
    print("mainDisplayDict:", mainDisplayDict)

    # 4) Add monthly % changes
    finalDisplayDict = process_percentchanges_per_month(mainDisplayDict)
    print("finalDisplayDict:", finalDisplayDict)

    # 5) Build the summary HTML
    summary_html = create_report_html(finalDisplayDict, BODY_HTML)
    print("summary_html (first 300 chars):", summary_html[:300])

    # 6) Per-service breakdown
    account_numbers = list(accountDict.keys())
    cost_data_Dict = get_cost_data(account_numbers)
    print("cost_data_Dict:", cost_data_Dict)

    display_cost_data_Dict = restructure_cost_data(cost_data_Dict, account_numbers)
    print("display_cost_data_Dict:", display_cost_data_Dict)

    breakdown_html = generate_html_table(cost_data_Dict, display_cost_data_Dict)
    print("breakdown_html (first 300 chars):", breakdown_html[:300])

    # Combine and send
    combined_html = summary_html + '<br><br>' + breakdown_html
    print("combined_html (first 300 chars):", combined_html[:300])

    send_report_email(combined_html)

    print("=== Completed Lambda Execution ===")

    return {
        'statusCode': 200,
        'body': 'Monthly Cost Report Sent!'
    }
