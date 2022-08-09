import requests
import json
import argparse

TOKEN_URL = "https://iam.cloud.ibm.com/identity/token"
BASE_CLOUD_URL = "https://{region}.iaas.cloud.ibm.com"


def get_access_token(api_key):
    headers = {
        'content-type': 'application/x-www-form-urlencoded',
        'accept': 'application/json',
    }
    body = {
        "grant_type": "urn:ibm:params:oauth:grant-type:apikey",
        "apikey": api_key
    }
    try:
        res_token = requests.post(url=TOKEN_URL, headers=headers, data=body)
        res_token.raise_for_status()
        return json.loads(res_token.content)
    except (requests.ConnectionError, requests.HTTPError) as err:
        raise err


def delete_security_group_rule(region, access_token, security_group_id, security_group_rule_id):
    url = f"{BASE_CLOUD_URL.format(region=region)}/v1/security_groups/{security_group_id}/rules/{security_group_rule_id}"
    params = (
        ('version', '2021-12-14'),
        ('generation', '2'),
    )
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    response = requests.delete(url=url, params=params, headers=headers)
    response.raise_for_status()
    return response.status_code


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Optional app description')
    parser.add_argument('--region', type=str, dest='region',
                        help='ibmcloud region', required=True)
    parser.add_argument('--apikey', type=str, dest='apikey',
                        help='ibmcloud apikey', required=True)
    parser.add_argument('--sg_id', type=str, dest='sg_id',
                        help='security group id', required=True)
    parser.add_argument('--sg_rule_id', type=str, dest='sg_rule_id',
                        help="security_group_rule_id", required=True)
    args = parser.parse_args()

    res = get_access_token(args.apikey)
    delete_security_group_rule(region=args.region, access_token=res.get("access_token"),
                               security_group_id=args.sg_id,
                               security_group_rule_id=args.sg_rule_id)
