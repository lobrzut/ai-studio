FROM python:3.12-slim-bookworm

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .

ENV WEB_DIR=/app/web
ENV DATA_DIR=/data
EXPOSE 7880

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7880"]
