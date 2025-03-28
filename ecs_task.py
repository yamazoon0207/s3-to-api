import json
import yaml
import boto3
import requests
import time
import os
from datetime import datetime, timezone

def process_json_file(s3_client, bucket, key):
    try:
        # S3からJSONファイルを取得
        response = s3_client.get_object(Bucket=bucket, Key=key)
        json_content = response['Body'].read().decode('utf-8')
        
        # JSONをPythonオブジェクトに変換
        data = json.loads(json_content)
        
        # PythonオブジェクトをYAMLに変換
        yaml_content = yaml.dump(data, allow_unicode=True, sort_keys=False)
        
        # YAMLをWeb APIにPUTリクエストで送信
        api_endpoint = os.environ.get('API_ENDPOINT', 'https://httpbin.org/put')
        api_response = requests.put(
            api_endpoint,
            data=yaml_content,
            headers={'Content-Type': 'application/x-yaml'}
        )
        
        print(f"Processed file {key}")
        print(f"API Response Status: {api_response.status_code}")
        
        if api_response.status_code == 200:
            # 処理済みのファイルを移動または削除
            new_key = f"processed/{key}"
            s3_client.copy_object(
                Bucket=bucket,
                CopySource={'Bucket': bucket, 'Key': key},
                Key=new_key
            )
            s3_client.delete_object(Bucket=bucket, Key=key)
            print(f"Moved {key} to processed/")
            
    except Exception as e:
        print(f'Error processing {key}: {str(e)}')

def main():
    # S3クライアントの初期化
    s3 = boto3.client('s3')
    
    # 環境変数から設定を取得
    bucket_name = os.environ.get('S3_BUCKET')
    file_key = os.environ.get('S3_FILE_KEY')
    
    if not bucket_name:
        raise ValueError("S3_BUCKET environment variable is required")
    if not file_key:
        raise ValueError("S3_FILE_KEY environment variable is required")
    
    print(f"Starting JSON to YAML converter task")
    print(f"Processing bucket: {bucket_name}")
    print(f"Processing file: {file_key}")
    
    try:
        # 特定のファイルを処理
        if file_key.endswith('.json') and not file_key.startswith('processed/'):
            print(f"Processing JSON file: {file_key}")
            process_json_file(s3, bucket_name, file_key)
            print("Task completed successfully")
        else:
            print(f"Skipping non-JSON file or already processed file: {file_key}")
    
    except Exception as e:
        print(f'Error in main process: {str(e)}')
        raise

if __name__ == "__main__":
    main()
