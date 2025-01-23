[ERROR] KeyError: '2024-04-01'
Traceback (most recent call last):
  File "/var/task/lambda_function.py", line 769, in lambda_handler
    mainDailyDict = process_costchanges_per_day(mainCostDict)
  File "/var/task/lambda_function.py", line 182, in process_costchanges_per_day
    reportCostDict[dayCost['TimePeriod']['Start']].update(

