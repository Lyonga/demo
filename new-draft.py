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

# Generate a list of monthly boundaries (the 1st) for the reporting window
MONTHLY_COST_DATES = []
temp_date = start_date
while temp_date < end_date:
    MONTHLY_COST_DATES.append(temp_date.strftime('%Y-%m-%d'))
    # Go to the next month by adding ~30 days, then forcing day=1
    next_month = (temp_date + timedelta(days=32)).replace(day=1)
    temp_date = next_month

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

        # Sum up the total cost across all monthly buckets
        period_cost = 0.0
        for month_data in response['ResultsByTime']:
            cost_val = float(month_data['Total']['UnblendedCost']['Amount'])
            period_cost += cost_val

        # Only store if cost > 0 for that period
        if period_cost > 0:
            accountCostDict[acct_id] = response

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

    return displayReportCostDict

# -----------------------------------------------------------------------------
# 5) CALCULATE PERCENT CHANGES MONTH-TO-MONTH (OPTIONAL)
# -----------------------------------------------------------------------------

def process_percentchanges_per_month(reportCostDict_input):
    """
    For each month (after the earliest), compute the percentage change relative to the previous month.
    Store it in 'percentDelta' for each account. If last month or current month cost = 0, store None.
    """
    # Convert all date keys to a sorted list so we can iterate in chronological order
    sorted_months = sorted(reportCostDict_input.keys())

    for i in range(len(sorted_months)):
        curr_month = sorted_months[i]
        # First month in the sorted list won't have a previous month to compare
        if i == 0:
            # Set all percentDelta to None
            for acct_id in reportCostDict_input[curr_month]:
                reportCostDict_input[curr_month][acct_id]['percentDelta'] = None
        else:
            prev_month = sorted_months[i - 1]
            # For each account in the current month
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

    return reportCostDict_input

# -----------------------------------------------------------------------------
# 6) CREATE HTML REPORT (SUMMARY TABLE)
# -----------------------------------------------------------------------------

def create_report_html(emailDisplayDict_input, BODY_HTML):
    """
    Builds an HTML summary table of monthly costs for each account in displayListMonthly,
    plus the Others row, plus the monthTotal row. Includes percentDelta if available.
    """

    # Helper for color-coding changes
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

    # Helper for alternating row color
    def row_color(i_row):
        return "<tr style='background-color:WhiteSmoke;'>" if (i_row % 2) == 0 else "<tr>"

    # Start building HTML table
    BODY_HTML += "<table border='1' style='border-collapse:collapse; font-family:Arial, sans-serif; font-size:12px;'>"

    # Header row 1
    BODY_HTML += "<tr style='background-color:SteelBlue;'>"
    BODY_HTML += "<td>&nbsp;</td>"  # top-left corner blank
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
            BODY_HTML += f"<td style='text-align:center;width:95px;'>{acct_id}</td>"
            BODY_HTML += "<td style='text-align:center;'>&Delta;%</td>"
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

        # For each month, output cost & change
        for acct_id in displayListMonthly:
            cost_val = emailDisplayDict_input[month_str].get(acct_id, {}).get('Cost', 0.0)
            pct_change = emailDisplayDict_input[month_str].get(acct_id, {}).get('percentDelta', None)

            # Cost Cell
            BODY_HTML += f"<td style='text-align:right; padding:4px;'>$ {cost_val:,.2f}</td>"
            # Delta Cell
            BODY_HTML += evaluate_change(pct_change)

        BODY_HTML += "</tr>"
        i_row += 1

    BODY_HTML += "</table><br>"
    # Optionally add a note or legend about the date range
    BODY_HTML += f"<div style='font-size:12px; font-style:italic;'>Reporting Window: {MONTHLY_START_DATE} to {MONTHLY_END_DATE}</div>"
    return BODY_HTML

# -----------------------------------------------------------------------------
# 7) OPTIONAL: GET LINKED ACCOUNTS (IF YOU NEED TO GROUP BY SERVICE LATER)
# -----------------------------------------------------------------------------

def get_linked_accounts(account_list):
    """
    Example function from original code to discover which accounts
    are active in the time period. For monthly usage, we reuse the same approach.
    """
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

    # Filter only those account IDs that are in your original list
    active_accounts = [item['Value'] for item in results]
    defined_accounts = [acct for acct in account_list if acct in active_accounts]
    return defined_accounts

# -----------------------------------------------------------------------------
# 8) OPTIONAL: GET COST DATA GROUPED BY ACCOUNT & SERVICE
# -----------------------------------------------------------------------------

def get_cost_data(account_numbers):
    """
    Example function from original code that retrieves monthly cost usage
    grouped by account and service.
    """
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

    return results

# -----------------------------------------------------------------------------
# 9) RESTRUCTURE COST DATA FOR PER-SERVICE BREAKDOWN (If desired)
# -----------------------------------------------------------------------------

def restructure_cost_data(cost_data_dict, account_numbers):
    """
    Turns the grouped cost data into a dict:
       { account_number : { service_name : { date : amount, ... }, ... }, ... }
    """
    display_cost_data_dict = {}

    # Initialize the outer dict
    for acct in account_numbers:
        display_cost_data_dict[acct] = {}

    # First collect all service names
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
                # Could happen if there's an empty cost or an unexpected account
                continue

    # Optionally sort service names (alphabetically)
    # or just return as-is
    sorted_dict = {}
    for acct_no, services in display_cost_data_dict.items():
        sorted_services = dict(sorted(services.items()))
        sorted_dict[acct_no] = sorted_services

    return sorted_dict

# -----------------------------------------------------------------------------
# 10) GENERATE HTML TABLE FOR PER-SERVICE BREAKDOWN (Optional advanced detail)
# -----------------------------------------------------------------------------

def generate_html_table(cost_data_dict, display_cost_data_dict):
    """
    Example function from original code that creates a detailed
    breakdown table by account, service, and monthly cost.
    """

    # We need a number of columns: each month has 1 cost column + 1 delta column (after first).
    # But let's keep it simpler and just replicate logic from original code:
    # Count the monthly buckets from 'cost_data_dict'.
    num_periods = len(cost_data_dict)  # each ResultsByTime item is a month
    # Each month has a cost column, except after the first month we also have a delta column
    # So total columns = (num_periods * 1) + (num_periods - 1) for deltas
    columns = (num_periods * 1) + (num_periods - 1)

    # Helper for color-coded delta
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
        return "<tr style='background-color: WhiteSmoke;'>" if (i_row % 2) == 0 else "<tr>"

    emailHTML = "<h2>AWS Monthly Cost Report - Per Service Breakdown</h2>"
    emailHTML += f'<table border="1" style="border-collapse:collapse; font-family:Arial,sans-serif;">'

    # For each account in your dictionary
    # We must keep track of months in the cost_data_dict (the "ResultsByTime" from get_cost_data)
    sorted_months = sorted([rbt['TimePeriod']['Start'] for rbt in cost_data_dict])

    for acct_id, services in display_cost_data_dict.items():
        # Account-level header
        acct_name = accountDict.get(acct_id, acct_id)
        emailHTML += f'<tr style="background-color:SteelBlue;"><td colspan="{columns}" style="text-align:center; font-weight:bold;">'
        emailHTML += f'{acct_name} ({acct_id})</td></tr>'

        # Subheader row for months
        emailHTML += '<tr style="background-color:LightSteelBlue;">'
        emailHTML += '<td style="text-align:center; font-weight:bold;">Service Name</td>'
        for idx, m in enumerate(sorted_months):
            # For each month, we have a cost column; after the first month, also add a delta col
            if idx > 0:
                emailHTML += '<td style="text-align:center;">Δ%</td>'
            emailHTML += f'<td style="text-align:center; font-weight:bold;">{m}</td>'
        emailHTML += '</tr>'

        # List each service row
        i_row = 0
        for svc, monthly_data in services.items():
            # Build a row for this service
            rsrcrowHTML = ''
            rsrcrowHTML += row_color(i_row)
            rsrcrowHTML += f'<td style="text-align:left;">{svc}</td>'

            prev_cost = None
            # For each month in sorted order
            for idx, m in enumerate(sorted_months):
                curr_cost = monthly_data.get(m, 0.0)
                if idx > 0:
                    # Evaluate delta if we have a previous cost
                    if prev_cost and prev_cost != 0 and curr_cost != 0:
                        pct_change = (curr_cost / prev_cost) - 1
                        rsrcrowHTML += evaluate_change(pct_change)
                    else:
                        rsrcrowHTML += '<td>&nbsp;</td>'

                rsrcrowHTML += f'<td style="text-align:right; padding:4px;">$ {curr_cost:,.2f}</td>'
                prev_cost = curr_cost

            rsrcrowHTML += '</tr>'

            # Hide the row entirely if it’s all zeros? (Optional)
            # We can check if all months had 0 cost. (Skipping for brevity.)

            emailHTML += rsrcrowHTML
            i_row += 1

    emailHTML += '</table>'
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
    SENDER = os.environ['SENDER']
    RECIPIENT = os.environ['RECIPIENT']
    AWS_REGION = os.environ['AWS_REGION']
    SUBJECT = "AWS Monthly Cost Report for Selected Accounts"
    BODY_TEXT = "AWS Cost Report (HTML Email)."

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
    # 1) Get summary cost info (per account)
    mainCostDict = ce_get_costinfo_per_account(accountDict)

    # 2) Re-sort the mainCostDict by month
    mainMonthlyDict = process_costchanges_per_month(mainCostDict)

    # 3) Create a "display" dictionary that includes 'Others' + 'monthTotal'
    mainDisplayDict = process_costchanges_for_display(mainMonthlyDict)

    # 4) Optionally compute monthly % changes
    finalDisplayDict = process_percentchanges_per_month(mainDisplayDict)

    # 5) Generate the summary HTML
    summary_html = create_report_html(finalDisplayDict, BODY_HTML)

    # -------------------------------------------------------------------------
    # (OPTIONAL) Get additional per-service breakdown
    # -------------------------------------------------------------------------
    # If you want a more granular per-service breakdown, you can do:
    #   account_numbers = list(accountDict.keys())  # or get_linked_accounts(accountDict.keys())
    #   cost_data_Dict = get_cost_data(account_numbers)
    #   display_cost_data_Dict = restructure_cost_data(cost_data_Dict, account_numbers)
    #   breakdown_html = generate_html_table(cost_data_Dict, display_cost_data_Dict)
    #   combined_html = summary_html + '<br><br>' + breakdown_html
    #
    # send_report_email(combined_html)
    #
    # For now, we’ll just send the summary_html:
    # -------------------------------------------------------------------------

    send_report_email(summary_html)

    return {
        'statusCode': 200,
        'body': 'Monthly Cost Report Sent!'
    }
