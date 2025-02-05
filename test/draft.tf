4. Step-by-Step Explanation of the Entire Code

Below is a simplified walkthrough of each major step:

    Global Setup
        We define the date range as the first day of the month minus MONTHSBACK*30 days, ensuring we get exactly 2 months.
        We set up some dictionaries like accountDict for which accounts we track.
        We define a TEAM_TAG_KEY and TEAM_TAG_VALUE so we can filter cost by that tag.

    ce_get_costinfo_per_account
        Retrieves overall monthly cost (no “GroupBy: SERVICE”), just total cost for each account in accountDict.
        Builds a dictionary keyed by account ID, storing the raw ResultsByTime from Cost Explorer.

    process_costchanges_per_month
        Takes that raw dictionary and reorganizes it by month (e.g. "2024-11-01": { acct: {...cost...}, ... }).
        Also calculates monthTotal.

    process_costchanges_for_display
        If you only want certain accounts or want to group everything else into “Others,” we do that here.
        For example, anything not in displayListMonthly is summed under 'Others'.

    process_percentchanges_per_month
        Compares consecutive months in the sorted list. For each account on the current month, calculates (current_cost / previous_cost) - 1.
        Stores that result as percentDelta.

    create_report_html
        Builds the summary HTML table for the monthly cost/deltas. This is the table you see in your screenshot.
        Row by row, it calls evaluate_change(value) to color code the deltas.

    get_cost_data / restructure_cost_data
        These produce a per-service breakdown for all usage.
        get_cost_data uses GroupBy=[(LINKED_ACCOUNT), (SERVICE)] and store raw results in results.
        restructure_cost_data organizes them into a dictionary like { acct_id: { service_name: { month: cost }}}.

    get_tagged_cost_data
        Same as get_cost_data, but uses a filter requiring the user-defined tag (TEAM_TAG_KEY=TEAM_TAG_VALUE). This yields usage only for resources with that tag.

    merge_team_data
        For each service, we look at the previous month’s cost and the current month’s cost in both the overall dictionary and the team dictionary.
        We compute:
            overallDeltaPct = (curr_overall / prev_overall) - 1
            teamDeltaPct = (curr_team / prev_team) - 1
            teamDeltaDollar = (curr_team - prev_team)
        Returns a dictionary with these values for each service.

    generate_html_table_with_team

    Produces a 5-column table:
        Service Name
        Overall Cost (this month)
        Overall Δ%
        Team Δ%
        Team Δ$
    Color-codes the percentage columns. If you want to color‐code the Δ$ as well, you add logic explained in question 1.

    lambda_handler

    Orchestrates everything:
        Creates the summary table.
        Fetches overall + tag-based per-service data.
        Merges them for each account.
        Builds the 5-column “Team vs. Overall” table.
        Concatenates the summary + breakdown into one HTML.
        Sends it via SES.

That’s the big picture. You end up with a single emailed report that has:

    A summary of monthly cost/deltas for each account.
    A detailed breakdown that shows each AWS service’s cost, comparing overall usage vs. team usage by tag.

Summary of Answers

    Team Δ$ Color: Store the previous team cost and color‐code the dollar difference by computing a ratio, reusing your existing threshold logic.
    80% Width: Wrap the HTML in a <div style="width:80%; margin:0 auto;">...</div> so it spans ~80% of the page.
    Strange Large Delta: Caused by small absolute amounts where previous_month is near 0. A jump from $0.0002 to $0.0005 can yield >100% growth. Rounding in the AWS console might show $0.00, but the ratio is huge.
    Step‐by‐Step: The script has distinct phases for retrieving cost data, organizing it monthly, computing deltas, building HTML tables, and merging team vs. overall usage.

Use these tips/snippets to fine‐tune your final cost‐reporting Lambda script!



Creates a Cost Explorer (CE) client to interact with AWS Cost Explorer.
We compute a 2-month window:

    start_date is the 1st of the earlier month.
    end_date is the 1st of the current month.
    This ensures we only get cost data for 2 distinct months to compare.



    def ce_get_costinfo_per_account(accountDict_input):
        # Loops each account in accountDict_input
        # Calls cost_explorer.get_cost_and_usage for each,
        # retrieving overall monthly cost (no "service" grouping).
        # Returns a dict keyed by account ID, containing the raw CE response.
        This specifically retrieves summed costs by account (no per-service breakdown here).
        Used for building the top-level summary of total monthly cost per account.

        def process_costchanges_per_month(accountCostDict_input):
            # Takes that dict from ce_get_costinfo_per_account
            # Reorganizes data so it's keyed by month -> account -> {Cost:xxx}
            # Also computes 'monthTotal'
We read each ResultsByTime, which might have structure like {"TimePeriod": {"Start":"2024-11-01"}, "Total":{...}}, to build:


def process_costchanges_for_display(reportCostDict_input):
    # Optionally merges "other" accounts into one
    # or ensures the dictionary only has the main accounts from displayListMonthly.
    If you have accounts in reportCostDict_input that aren’t in displayListMonthly, it lumps those costs under 'Others'.

Example:
If we only want to highlight Dev, QA, Prod, and monthTotal, everything else gets grouped into “Others.”


def process_percentchanges_per_month(reportCostDict_input):
    # Sort months, for each month i>0, compute (curr_cost / prev_cost) - 1
    # Stores that in 'percentDelta'
    Example: If month i has cost $200 and month i-1 has cost $100, percentDelta=1.0 (or 100%).
    This is used in the final summary HTML to color-code the summary table.



    def create_report_html(emailDisplayDict_input, BODY_HTML):
        # Builds the final "summary" table of monthly cost + delta for each account
        # Called "the table that looks like your screenshot"
        Takes the finalDisplayDict (which includes percentDelta) and renders a table with columns for each account ID, plus a row for each month.
        evaluate_change(value) is a small function that color-codes the HTML cell depending on how big/small the percent change is.



        def get_linked_accounts(account_list):
            # Possibly used if you want to discover which accounts are active
            # in the payer account. Not crucial if you already know which accounts you have.
Often not strictly needed, but can be used if you only want to query accounts that exist in your AWS Organization.


def get_cost_data(account_numbers):
    # Calls cost_explorer.get_cost_and_usage with GroupBy=[LINKED_ACCOUNT, SERVICE]
    # So we get monthly cost broken down by each account and service.
    This returns a list of data (results), each element has a TimePeriod and a list of Groups.
    Used to build the per-service breakdown for the entire cost (no tag filter).


    def get_tagged_cost_data(account_numbers, tag_key, tag_value):
        # Same as get_cost_data, but uses a "Filter" that requires each resource
        # to match tag_key=tag_value. So only returns cost for resources with that tag.
        This is how we get the cost for team resources (like Project=core).
        We again group by [LINKED_ACCOUNT, SERVICE].



        def restructure_cost_data(cost_data_dict, account_numbers):
            # Turns the raw CE "ResultsByTime" (with 'Groups') into
            # { acct_id: { service_name: { date_str: cost } } }
This is a step to reorganize your data into a dictionary that’s easy to compare month→month for each service.



def merge_team_data(overall_dict, team_dict):
    """
    For each service, we have two months in both 'overall_dict' and 'team_dict'.
    We:
    1) Identify prev_m and curr_m (two months).
    2) Invert the sign so cost increases yield negative. (You changed the logic.)
    3) Return a dictionary with "overallDeltaPct", "teamDeltaPct",
       "teamDeltaDollar", etc. for each service.
    """
    Specifically:

        We figure out the earliest month as prev_m, the next as curr_m.
        For each service svc:
            prev_overall / curr_overall = the usage for the 2 months in the overall data.
            prev_team / curr_team = usage in the tag-filtered (team) data.
            We compute your custom “inverted” delta:
                e.g., overall_delta = (prev_overall / curr_overall) - 1.
                e.g., team_delta_dollar = prev_team - curr_team => negative if usage is up from last to current.
                e.g., team_delta_pct = (prev_team / curr_team) - 1.
        Return a dictionary keyed by service, with these computed fields.





        def generate_html_table_with_team(final_info, acct_no):
            # Creates an HTML table with columns:
            #   Service Name | Overall Cost | Overall Δ% | Team Δ% | Team Δ$
            # Color-coded using evaluate_change(value).

            For each service (key in final_info), we fill in a row with:

                Service name
                Overall cost in the current month
                Overall Δ% (negative if usage is up, based on your new logic)
                Team Δ% (again negative if usage is up)
                Team Δ$

            This is appended into an <html> table that’s eventually included in the final email body.




            def send_report_email(BODY_HTML):
                # Uses the SES client with environment variables (SENDER, RECIPIENT, etc.)
                # Sends the final HTML to an email

                Straightforward function to deliver the final combined HTML report via Amazon SES.

            14. lambda_handler

            Finally, your lambda_handler orchestrates all these steps:

                ce_get_costinfo_per_account → mainCostDict
                process_costchanges_per_month → reorganize → mainMonthlyDict
                process_costchanges_for_display → group accounts → mainDisplayDict
                process_percentchanges_per_month → compute deltas → finalDisplayDict
                    This is specifically for the top summary table.
                create_report_html → build an HTML summary table → summary_html

            Then for per-service breakdown:

                get_cost_data → gather overall usage by service → cost_data_Dict.
                    restructure_cost_data → display_cost_data_Dict.
                get_tagged_cost_data → gather team usage by service → team_data_Dict.
                    restructure_cost_data → display_team_data_Dict.
                For each account:
                    merge_team_data(overall, team) → a dictionary of usage + deltas.
                    generate_html_table_with_team(…) → an HTML table for that account.
                    Append to breakdown_html.

            Finally:

                Combine the summary + breakdown into one big HTML string:

                combined_html = "<div style='width:80%; margin:0 auto;'>" + summary_html + "<br><br>" + breakdown_html + "</div>"

                send_report_email(combined_html)
                    Delivers the final result via SES.

            Return:

            {"statusCode": 200, "body": "Monthly Cost Report Sent!"}

            That’s it—your monthly cost plus inverted deltas for each service, both overall and by tag.
            Overall Logic in Plain English

                We pick a 2-month window (the 1st of last month to the 1st of this month).
                We retrieve total monthly cost for each account to build the summary table.
                We retrieve per-service cost data for all resources → overall, and again for only resources with a specific tag → team.
                We reorganize each set so we can compare previous vs. current month for each service.
                Because you want the sign flipped if usage/cost goes up, we do (prev / curr) - 1 and (prev_team - curr_team) etc.
                We produce an HTML table for each account listing these columns:
                    Service Name
                    Overall Cost (current month)
                    Overall Δ% (negative if cost is higher)
                    Team Δ% (negative if cost is higher)
                    Team Δ$ (negative if cost is higher)
                We email the entire report via SES.

            This completes the entire pipeline from retrieving cost data to delivering an HTML cost comparison with negative deltas on rising costs!
