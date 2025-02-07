import pymssql
import boto3
import os
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    if 'SecretString' in response:
        secret = json.loads(response['SecretString'])
        return secret
    else:
        raise ValueError("SecretsManager response did not contain SecretString.")


def handler(event, context):
    db_name = os.getenv('DB_NAME')
    s3_bucket = os.getenv('S3_BUCKET')
    s3_keys = os.getenv('S3_KEYS')
    secret_name = os.getenv('RDS_SECRETS')
    secret = get_secret(secret_name)
    rds_host = os.getenv('DB_ENDPOINT')
    db_user = secret['username']
    db_password = secret['password']

    try:
        conn = pymssql.connect(server=rds_host, user=db_user, password=db_password, database='master', autocommit=True)
        cursor = conn.cursor()

        restore_command = f"""
        exec msdb.dbo.rds_restore_database
            @restore_db_name='{db_name}',
            @s3_arn_to_restore_from='arn:aws:s3:::{s3_bucket}/{s3_keys}';
        """
        cursor.execute(restore_command)

        conn.commit()
        cursor.close()
        conn.close()

        return {
            'statusCode': 200,
            'body': 'Database restore initiated successfully'
        }

    except pymssql.Error as e:
        error_message = f"pymssql error: {str(e)}"
        print(error_message)
        return {
            'statusCode': 500,
            'body': error_message
        }

    except Exception as e:
        error_message = f"Unexpected error: {str(e)}"
        print(error_message)
        return {
            'statusCode': 500,
            'body': error_message
        }
