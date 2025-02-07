import pymssql
import os
import boto3
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
    rds_secret_env_var = os.getenv('RDS_SECRETS')
    db_secret_env_var = os.getenv('DB_SECRETS')

    rds_secret = get_secret(rds_secret_env_var)
    db_secret = get_secret(db_secret_env_var)
    
    rds_host = os.getenv('DB_ENDPOINT')
    db_user = rds_secret['username']
    db_password = rds_secret['password']
    db_name = 'master'

    new_db_name = db_secret['database']
    new_username = db_secret['username']
    new_user_password = db_secret['password']

    try:
        # Connect to the RDS instance as master user
        conn_master = pymssql.connect(server=rds_host, user=db_user, password=db_password, database=db_name, autocommit=True)

        # Create a cursor object using the master connection
        cursor_master = conn_master.cursor()

        # Check if database already exists in the master database
        cursor_master.execute(f"SELECT name FROM sys.databases WHERE name = '{new_db_name}'")
        existing_db = cursor_master.fetchone()

        if not existing_db:
            # Close the connection to the master database before creating new database
            conn_master.close()

            # Reconnect to master to execute the CREATE DATABASE outside transaction context
            conn_master = pymssql.connect(server=rds_host, user=db_user, password=db_password, database=db_name, autocommit=True)
            cursor_master = conn_master.cursor()

            # Create new database with case-sensitive and accent-sensitive collation
            cursor_master.execute(f"CREATE DATABASE {new_db_name} COLLATE SQL_Latin1_General_CP1_CS_AS;")
            print(f"Database '{new_db_name}' created successfully with collation SQL_Latin1_General_CP1_CS_AS.")

        else:
            print(f"Database '{new_db_name}' already exists.")

        # Close the connection to the master database
        conn_master.close()

        # Connect to the newly created database with master credentials
        conn_new_db = pymssql.connect(server=rds_host, user=db_user, password=db_password, database=new_db_name, autocommit=True)
        cursor_new_db = conn_new_db.cursor()

        # Check if login already exists
        cursor_new_db.execute(f"SELECT name FROM sys.server_principals WHERE name = '{new_username}'")
        existing_login = cursor_new_db.fetchone()

        if not existing_login:
            # Create new login
            cursor_new_db.execute(f"CREATE LOGIN {new_username} WITH PASSWORD = '{new_user_password}', CHECK_POLICY = OFF;")
            print(f"Login '{new_username}' created successfully.")
        else:
            print(f"Login '{new_username}' already exists.")

        # Check if user already exists in the database
        cursor_new_db.execute(f"SELECT name FROM sys.database_principals WHERE name = '{new_username}'")
        existing_user = cursor_new_db.fetchone()

        if not existing_user:
            # Create new user for the login
            cursor_new_db.execute(f"CREATE USER [{new_username}] FOR LOGIN [{new_username}];")
            print(f"User '{new_username}' created successfully.")

            # Grant permissions (SELECT, INSERT, UPDATE, DELETE) on schema::dbo
            cursor_new_db.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [{new_username}];")
            print(f"Permissions granted to user '{new_username}' on schema dbo.")

            # Optionally, create a new schema and grant permissions on it
            new_schema_name = 'new_user_schema'
            cursor_new_db.execute(f"CREATE SCHEMA [{new_schema_name}];")
            cursor_new_db.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[{new_schema_name}] TO [{new_username}];")
            print(f"Schema '{new_schema_name}' created and permissions granted to user '{new_username}'.")

            # Commit the transaction
            conn_new_db.commit()

        else:
            print(f"User '{new_username}' already exists in the database.")

        # Close the connection to the newly created database
        conn_new_db.close()

        return {
            'statusCode': 200,
            'body': f'New database, user, and permissions created successfully'
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
