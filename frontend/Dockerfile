FROM python:3.10-slim
WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

ENV PORT 8080
ENV GOOGLE_APPLICATION_CREDENTIALS=/app/service-account.json

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]
