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
    secret_name = os.getenv('RDS_SECRETS')
    secret = get_secret(secret_name)

    rds_endpoint = os.getenv('DB_ENDPOINT')
    rds_user = secret['username']
    rds_password = secret['password']
    
    try:
        # Connect to the RDS instance
        conn = pymssql.connect(server=rds_endpoint, user=rds_user, password=rds_password)
        cursor = conn.cursor()
        
        # Query to retrieve database names and their sizes
        cursor.execute("""
            SELECT 
                DB_NAME(database_id) AS DatabaseName,
                SUM(size * 8.0 / 1024) AS SizeMB
            FROM 
                sys.master_files
            WHERE 
                type = 0  -- 0 = Rows Data File, 1 = Log File
            GROUP BY 
                database_id
        """)
        
        # Fetch all rows
        rows = cursor.fetchall()
        
        # Print or process the database names and sizes
        for row in rows:
            db_name = row[0]
            db_size_mb = row[1]
            db_size_gb = db_size_mb / 1024  # Convert MB to GB
            print(f"Database: {db_name}, Size: {db_size_gb:.2f} GB")
        
        # Close cursor and connection
        cursor.close()
        conn.close()
        
        return {
            'statusCode': 200,
            'body': 'Successfully retrieved database sizes'
        }
    
    except pymssql.Error as e:
        print(f"pymssql error: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error retrieving database sizes: {str(e)}'
        }

    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Unexpected error: {str(e)}'
        }
