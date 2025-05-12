from flask import Flask, render_template, request, redirect
from google.cloud import storage, bigquery
from werkzeug.utils import secure_filename

import os

PROJECT_ID = os.environ.get('PROJECT_ID')
BUCKET_NAME = os.environ.get('BUCKET_NAME')
DATASET_NAME = os.environ.get('DATASET_NAME')
TABLE_NAME = os.environ.get('TABLE_NAME')


app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB limit
app.config['UPLOAD_EXTENSIONS'] = ['.pdf', '.jpg', '.jpeg', '.png']

# Initialize clients
storage_client = storage.Client(project=PROJECT_ID)
bucket = storage_client.bucket(BUCKET_NAME)
bq_client = bigquery.Client(project=PROJECT_ID)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    uploaded_file = request.files['file']
    filename = secure_filename(uploaded_file.filename)
    
    if filename != '':
        file_ext = os.path.splitext(filename)[1]
        if file_ext not in app.config['UPLOAD_EXTENSIONS']:
            return "Invalid file type", 400

        blob = bucket.blob(filename)
        # Set the correct content type
        content_type = uploaded_file.content_type or 'application/pdf'
        blob.upload_from_file(uploaded_file, content_type=content_type)
        
    return redirect('/results')

@app.route('/results')
def show_results():
    query = f"""
        SELECT * 
        FROM `{PROJECT_ID}.{DATASET_NAME}.{TABLE_NAME}`
    """
    results = bq_client.query(query).result()
    return render_template('results.html', results=results)
