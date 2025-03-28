FROM python:3.11-slim

WORKDIR /app

# 必要なパッケージをインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY ecs_task.py .

# 実行権限を付与
RUN chmod +x ecs_task.py

# コンテナ起動時にPythonスクリプトを実行
CMD ["python", "ecs_task.py"]
