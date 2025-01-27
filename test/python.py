def get_cost_data_for_tag(account_numbers, tag_key, tag_value):
    """
    Similar to get_cost_data, but filters only resources with a given tag_key=tag_value.
    E.g., tag_key='project', tag_value='Traverse'.
    """
    print(f"get_cost_data_for_tag called with accounts={account_numbers}, tag={tag_key}={tag_value}")
    results = []
    token = None

    # Build the combined Filter for LINKED_ACCOUNT + Tag
    combined_filter = {
        "And": [
            {
                "Dimensions": {
                    "Key": "LINKED_ACCOUNT",
                    "Values": account_numbers
                }
            },
            {
                "Tags": {
                    "Key": tag_key,
                    "Values": [tag_value]
                }
            }
        ]
    }

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
            Filter=combined_filter,
            **kwargs
        )
        results += data['ResultsByTime']
        token = data.get('NextPageToken')
        if not token:
            break

    print("Completed get_cost_data_for_tag.")
    print("\n[DEBUG] get_cost_data_for_tag() return value:")
    print(results)

    return results



def lambda_handler(event=None, context=None):
    ...
    # 6) Per-service breakdown for all resources
    # cost_data_Dict = get_cost_data(account_numbers)

    # 6A) Alternatively, per-service breakdown *only* for `project=Traverse`:
    tag_key = "project"
    tag_value = "Traverse"
    cost_data_Dict = get_cost_data_for_tag(account_numbers, tag_key, tag_value)

    # Then reuse the same restructure_cost_data + generate_html_table
    display_cost_data_Dict = restructure_cost_data(cost_data_Dict, account_numbers)
    breakdown_html = generate_html_table(cost_data_Dict, display_cost_data_Dict)
    ...




def save_report_to_s3(html_data, bucket_name, object_key):
    """
    Saves the HTML data to S3 as an object (e.g. "cost-reports/report.html").
    Make sure your Lambda has s3:PutObject permission for this bucket.
    """
    s3 = boto3.client('s3')
    s3.put_object(
        Bucket=bucket_name,
        Key=object_key,
        Body=html_data.encode("utf-8"),  # ensure bytes
        ContentType='text/html'
    )
    print(f"Report saved to s3://{bucket_name}/{object_key}")


#############

Filter={
  "And": [
    {"Dimensions": {"Key": "LINKED_ACCOUNT","Values": ...}},
    {"Tags": {"Key": "project","Values": ["Traverse"]}}
  ]
}
