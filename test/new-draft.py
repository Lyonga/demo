def process_costchanges_per_month(accountCostDict_input):
    reportCostDict = {}  # Dictionary for storing monthly costs

    # Create a dictionary for every month in the reporting period
    for date in MONTHLY_COST_DATES:
        reportCostDict[date] = {}

    # Fill each monthly dictionary with Account:Cost key-value pairs
    for key in accountCostDict_input:
        for monthCost in accountCostDict_input[key]['ResultsByTime']:
            start_date = monthCost['TimePeriod']['Start']
            # Initialize the month if it doesn't exist in reportCostDict
            if start_date not in reportCostDict:
                reportCostDict[start_date] = {}
            # Add account cost
            reportCostDict[start_date][key] = {
                'Cost': float(monthCost['Total']['UnblendedCost']['Amount'])
            }

    # Calculate total cost per month
    for date in reportCostDict:
        month_total = sum(
            account['Cost'] for account in reportCostDict[date].values()
        )
        reportCostDict[date]['monthTotal'] = {'Cost': month_total}

    return reportCostDict






##############
mainMonthlyDict = process_costchanges_per_month(mainCostDict)
