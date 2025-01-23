import boto3
import os
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# -----------------------------------------------------------------------------
# 1) GLOBAL CONSTANTS AND SETUP
# -----------------------------------------------------------------------------

# Initialize the Cost Explorer client
cost_explorer = boto3.client('ce')

# For monthly cost reporting, define how many months back to report
MONTHSBACK = 9  # e.g., 9 months back

# Determine the first day of the current month
today = datetime.now()
first_of_this_month = today.replace(day=1)

# The start date is "MONTHSBACK months ago," adjusted to the 1st of that month
start_date = (first_of_this_month - timedelta(days=MONTHSBACK * 30)).replace(day=1)
end_date = first_of_this_month  # i.e., 1st day of current month

# Convert these to strings for Cost Explorer
MONTHLY_START_DATE = start_date.strftime('%Y-%m-%d')
MONTHLY_END_DATE = end_date.strftime('%Y-%m-%d')

print(f"Monthly reporting range: {MONTHLY_START_DATE} to {MONTHLY_END_DATE}")

# Generate a list of monthly boundaries (the 1st) for the reporting window
MONTHLY_COST_DATES = []
temp_date = start_date
while temp_date < end_date:
    MONTHLY_COST_DATES.append(temp_date.strftime('%Y-%m-%d'))
    next_month = (temp_date + timedelta(days=32)).replace(day=1)
    temp_date = next_month

print("MONTHLY_COST_DATES:", MONTHLY_COST_DATES)

# These are the AWS accounts you want to track, with friendly names
accountDict = {
    '384352530920': 'AWS-Workloads-Dev',
    '454229460814': 'AWS-Workloads-QA',
    '235163852221': 'AWS-Workloads-Prod'
}

# (Optional) Email mapping if you need to send separate mails per account
accountMailDict = {
    '384352530920': 'clyonga@nglic.com',
    '454229460814': 'clyonga@nglic.com',
    '235163852221': 'clyonga@nglic.com'
}

# This display list indicates how columns will appear in the summary
# The final 'monthTotal' is a synthetic key for total monthly cost
displayListMonthly = [
    '384352530920',
    '454229460814',
    '235163852221',
    'monthTotal'
]

# A base HTML heading for your email
BODY_HTML = '<h2>AWS Monthly Cost Report for Accounts - Summary</h2>'

# -----------------------------------------------------------------------------
# 2) RETRIEVE COST INFO PER ACCOUNT (Summary)
# -----------------------------------------------------------------------------

def ce_get_costinfo_per_account(accountDict_input):
    """
    For each account in accountDict_input, call Cost Explorer with Granularity=MONTHLY.
    Return a dictionary keyed by account ID, containing the Cost Explorer response.
    """
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

        # Print the raw response for debugging (comment out if too verbose)
        # print(response)

        # Sum up the total cost across all monthly buckets
        period_cost = 0.0
        for month_data in response['ResultsByTime']:
            cost_val = float(month_data['Total']['UnblendedCost']['Amount'])
            period_cost += cost_val

        print(f"Cost of account {acct_id} for the period {MONTHLY_START_DATE} to {MONTHLY_END_DATE} is: {period_cost}")

        # Only store if cost > 0 for that period
        if period_cost > 0:
            accountCostDict[acct_id] = response

    print("Completed ce_get_costinfo_per_account. accountCostDict keys:", list(accountCostDict.keys()))
    return accountCostDict

# -----------------------------------------------------------------------------
# 3) CREATE A MONTHLY-KEYED DICTIONARY OF COSTS
# -----------------------------------------------------------------------------

def process_costchanges_per_month(accountCostDict_input):
    """
    Takes the dictionary from ce_get_costinfo_per_account and reorganizes it
    into a dictionary keyed by each month's start date, containing per-account costs.
    Also adds 'monthTotal' to each month's dict.
    """
    reportCostDict = {}

    # Initialize dictionary for each monthly boundary in the window
    for date_str in MONTHLY_COST_DATES:
        reportCostDict[date_str] = {}

    # Populate monthly costs
    for acct_id, response_data in accountCostDict_input.items():
        for month_data in response_data['ResultsByTime']:
            start_str = month_data['TimePeriod']['Start']
            if start_str not in reportCostDict:
                reportCostDict[start_str] = {}
            reportCostDict[start_str][acct_id] = {
                'Cost': float(month_data['Total']['UnblendedCost']['Amount'])
            }

    # Calculate monthly total
    for date_str in reportCostDict:
        month_total = 0.0
        for acct_id in reportCostDict[date_str]:
            month_total += reportCostDict[date_str][acct_id]['Cost']
        reportCostDict[date_str]['monthTotal'] = {'Cost': month_total}

    print("Completed process_costchanges_per_month. Keys in reportCostDict:", list(reportCostDict.keys()))
    return reportCostDict

# -----------------------------------------------------------------------------
# 4) FORMAT COSTS FOR "DISPLAY" (E.G. SHOW ONLY SPECIFIC ACCOUNTS & 'Others')
# -----------------------------------------------------------------------------

def process_costchanges_for_display(reportCostDict_input):
    """
    Takes the monthly dictionary from process_costchanges_per_month,
    merges lesser-seen accounts into 'Others' unless they're in displayListMonthly.
    Returns a dictionary with the same months, but only the keys in displayListMonthly + 'Others'.
    """
    displayReportCostDict = {}

    for date_str in reportCostDict_input:
        displayReportCostDict[date_str] = {}
        others_cost = 0.0

        for acct_id, cost_obj in reportCostDict_input[date_str].items():
            if acct_id in displayListMonthly:
                displayReportCostDict[date_str][acct_id] = cost_obj
            else:
                others_cost += cost_obj['Cost']

        # Add 'Others' line for any accounts not in displayListMonthly
        displayReportCostDict[date_str]['Others'] = {'Cost': others_cost}

    print("Completed process_costchanges_for_display.")
    return displayReportCostDict

# -----------------------------------------------------------------------------
# 5) CALCULATE PERCENT CHANGES MONTH-TO-MONTH
# -----------------------------------------------------------------------------

def process_percentchanges_per_month(reportCostDict_input):
    """
    For each month (after the earliest), compute the percentage change relative to the previous month.
    Store it in 'percentDelta' for each account. If last month or current month cost = 0, store None.
    """
    sorted_months = sorted(reportCostDict_input.keys())
    print("Calculating percent changes across months:", sorted_months)

    for i in range(len(sorted_months)):
        curr_month = sorted_months[i]
        if i == 0:
            # First month in the list won't have a previous month
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
    return reportCostDict_input

# -----------------------------------------------------------------------------
# 6) CREATE HTML REPORT (SUMMARY TABLE)
# -----------------------------------------------------------------------------

def create_report_html(emailDisplayDict_input, BODY_HTML):
    """
    Builds an HTML summary table of monthly costs for each account in displayListMonthly,
    plus the Others row, plus the monthTotal row. Includes percentDelta if available.
    """

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

    # Sort the months in ascending order
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
    return BODY_HTML

# -----------------------------------------------------------------------------
# 7) OPTIONAL: GET LINKED ACCOUNTS (PER-SERVICE GROUPING)
# -----------------------------------------------------------------------------

def get_linked_accounts(account_list):
    """
    Discovers which accounts are active in the time period, based on dimension values.
    """
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
    return defined_accounts

# -----------------------------------------------------------------------------
# 8) GET COST DATA GROUPED BY ACCOUNT & SERVICE (PER-SERVICE BREAKDOWN)
# -----------------------------------------------------------------------------

def get_cost_data(account_numbers):
    """
    Retrieves monthly cost usage grouped by account and service.
    """
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
    return results

# -----------------------------------------------------------------------------
# 9) RESTRUCTURE COST DATA FOR PER-SERVICE BREAKDOWN
# -----------------------------------------------------------------------------

def restructure_cost_data(cost_data_dict, account_numbers):
    """
    Turns the grouped cost data into a dict:
       { account_number : { service_name : { date : amount, ... }, ... }, ... }
    """
    print("restructure_cost_data called.")
    display_cost_data_dict = {}

    # Initialize the outer dict
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
            else:
                continue

    # Sort service names for each account
    sorted_dict = {}
    for acct_no, services in display_cost_data_dict.items():
        sorted_services = dict(sorted(services.items()))
        sorted_dict[acct_no] = sorted_services

    print("Completed restructure_cost_data.")
    return sorted_dict

# -----------------------------------------------------------------------------
# 10) GENERATE HTML TABLE FOR PER-SERVICE BREAKDOWN
# -----------------------------------------------------------------------------

def generate_html_table(cost_data_dict, display_cost_data_dict):
    """
    Creates a detailed breakdown table by account, service, and monthly cost.
    Includes cost and % delta between months.
    """
    print("generate_html_table called.")

    # Identify the monthly buckets from cost_data_dict
    sorted_months = sorted([rbt['TimePeriod']['Start'] for rbt in cost_data_dict])

    # Each month has 1 cost column; after the first month, we also have a delta column
    # So total columns = (num_months * 1) + (num_months - 1)
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

        # Subheader row for months
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
                    # Evaluate delta
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
    return emailHTML

# -----------------------------------------------------------------------------
# 11) SEND REPORT VIA SES
# -----------------------------------------------------------------------------

def send_report_email(BODY_HTML):
    """
    Sends the HTML report via Amazon SES. Relies on environment variables:
      - SENDER: The 'From' address (must be verified in SES)
      - RECIPIENT: The 'To' address
      - AWS_REGION: AWS region for SES
    """
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
        print(e.response['Error']['Message'])

# -----------------------------------------------------------------------------
# 12) LAMBDA HANDLER
# -----------------------------------------------------------------------------

def lambda_handler(event=None, context=None):
    print("=== Starting Lambda Execution ===")
    # 1) Get summary cost info (per account)
    mainCostDict = ce_get_costinfo_per_account(accountDict)
    print("mainCostDict:", mainCostDict)

    # 2) Re-sort the mainCostDict by month
    mainMonthlyDict = process_costchanges_per_month(mainCostDict)
    print("mainMonthlyDict:", mainMonthlyDict)

    # 3) Create a "display" dictionary that includes 'Others' + 'monthTotal'
    mainDisplayDict = process_costchanges_for_display(mainMonthlyDict)
    print("mainDisplayDict:", mainDisplayDict)

    # 4) Optionally compute monthly % changes
    finalDisplayDict = process_percentchanges_per_month(mainDisplayDict)
    print("finalDisplayDict:", finalDisplayDict)

    # 5) Generate the summary HTML
    summary_html = create_report_html(finalDisplayDict, BODY_HTML)

    # -------------------------------------------------------------------------
    # 6) Optional: Include a more granular per-service breakdown
    # -------------------------------------------------------------------------
    # Find the active accounts (in case you only want to break down active ones)
    account_numbers = list(accountDict.keys())  # Or get_linked_accounts(accountDict.keys())

    # Retrieve monthly cost data grouped by account & service
    cost_data_Dict = get_cost_data(account_numbers)
    print("cost_data_Dict:", cost_data_Dict)

    # Restructure the cost data
    display_cost_data_Dict = restructure_cost_data(cost_data_Dict, account_numbers)
    print("display_cost_data_Dict:", display_cost_data_Dict)

    # Create the per-service breakdown HTML
    breakdown_html = generate_html_table(cost_data_Dict, display_cost_data_Dict)

    # Combine summary + breakdown
    combined_html = summary_html + '<br><br>' + breakdown_html

    # 7) Send the email
    send_report_email(combined_html)

    print("=== Completed Lambda Execution ===")

    return {
        'statusCode': 200,
        'body': 'Monthly Cost Report Sent!'
    }
