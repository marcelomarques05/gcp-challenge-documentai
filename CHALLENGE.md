# GCP Document AI Challenge

## ℹ️ INFORMATION

- ✅ **Services are already enabled on the project**
- 📍 **All resources must be in the same REGION/LOCATION**
- 🌍 **Location Suggestion**: `us`
- 🌍 **Region Suggestion**: `us-central1`

---

## 🛠️ Step-by-Step Instructions

### 1. Access GCP Console 🌐

<details>
  <summary>Click to view</summary>
  
  1. <p>Go to <a href="https://console.cloud.google.com" target="_blank">https://console.cloud.google.com</a></p>  

</details>

---

### 2. Select the Project 🏗️

<details>
  <summary>Click to view</summary>
  
  1. <p>Click on the project selector at the top of the page.</p>

  2. <p>Select the project. (<i>it will be informed during the session</i>)</p>

</details>

---

### 3. Create 2 Buckets (One for the Function and one for EventArc) on Cloud Storage 🪣

**Bucket names**:</p>

- `challenge-main-XXXX` _(for the Cloud Function)_
- `challenge-trigger-XXXX` _(for the EventArc)_

<details>
  <summary>Click to view</summary>
  
  1. <p>Go to <a href="https://console.cloud.google.com/storage/browser" target="_blank">Cloud Storage</a></p>
  2. <p>Click on "Create"</p>
  3. <p>Add the name for the first bucket (<code>challenge-main-XXXX</code>)</p>
  4. <p>Click "Create at the bottom</p>
  5. <p>Repeat the process for the second bucket (<code>challenge-trigger-XXXX</code>)</p>

</details>

---

### 4. Create a Docker Repository in Artifact Registry 🐳

**Repository name**:  

- `challenge-repo-XXXX`

<details>
  <summary>Click to view</summary>
  
  1. <p>Go to <a href="https://console.cloud.google.com/artifacts" target="_blank">Artifact Registry</a></p>
  2. <p>Click on "Create Repository"</p>
  3. <p>Enter the repository name (<code>challenge-repo-XXXX</code>)</p>
  4. <p>Choose <code>Docker</code> as the format</p>
  5. <p>Set the location to <code>us-central1</code></p>
  6. <p>Click "Create"</p>

</details>

---

### 5. Create 2 Service Accounts (one for the Function and one for EventArc) 🧑‍💻

**SA Names**:  

- `challenge-webhook-sa-XXXX` _(for the Cloud Function)_
- `challenge-trigger-sa-XXXX` _(for the EventArc)_

<details>
  <summary>Click to view</summary>
  
  1. <p>Go to <a href="https://console.cloud.google.com/iam-admin/serviceaccounts" target="_blank">IAM & Admin → Service Accounts</a></p>
  2. <p>Select again the project you created on the project selector</p>
  3. <p>Click on "Create Service Account"</p>
  4. <p>Enter the service account ID</p>
  5. <p>Click "Done"</p>
  6. <p>Repeat the process for the second service account</p>

</details>

---

### 6. Assign Roles to Webhook/Function Service Account 🔐

Grant these roles:

- `roles/aiplatform.serviceAgent`
- `roles/bigquery.dataEditor`
- `roles/documentai.admin`

<details>
  <summary>Click to view</summary>
  
  1. <p>In the service accounts page, find the service account you created for the Cloud Function</p>
  2. <p>Click on the service account name</p>
  3. <p>Go to the "Permissions" tab</p>
  4. <p>Click on "Manage access"</p>
  5. <p>Click on "Add role"</p>
  6. <p>Search for the roles mentioned above and select them</p>
  7. <p>Click on "Add another role" for each role</p>
  8. <p>Once all roles are added, click "Save"</p>

</details>

---

### 7. Assign Roles to Trigger/EventArc Service Account 🔐

Grant these roles:

- `roles/eventarc.eventReceiver`
- `roles/run.invoker`

  1. <p>In the service accounts page, find the service account you created for the Cloud Function</p>
  2. <p>Click on the service account name</p>
  3. <p>Go to the "Permissions" tab</p>
  4. <p>Click on "Manage access"</p>
  5. <p>Click on "Add role"</p>
  6. <p>Search for the roles mentioned above and select them</p>
  7. <p>Click on "Add another role" for each role</p>
  8. <p>Once all roles are added, click "Save"</p>

</details>

---

### 8. Assign Role to Google Storage Service Account 🔐

Grant the role:

- `roles/pubsub.publisher`  
  _(Ignore the “Outdated” message)_

<details>
  <summary>Click to view</summary>
  
  1. <p>Go to <a href="https://console.cloud.google.com/storage/settings" target="_blank">Cloud Storage → Settings</a></p>
  2. <p>Copy the <i>Cloud Storage Service Account</i></p>
  3. <p>Go to <a href="https://console.cloud.google.com/iam-admin/iam" target="_blank">IAM & Admin → IAM</a></p>
  4. <p>Click on "Grant Access"</p>
  5. <p>Paste the GCS Service Account email <i>(you will see two with same name, don't worry, both are the same)</i></p>
  6. <p>Click "Select a role"</p>
  7. <p>Search for <code>Pub/Sub Publisher</code> and select it</p>
  8. <p>Click "Save"</p>

</details>

---

### 9. Create BigQuery Dataset and Table 📊

- **Dataset name**: `challenge_dataset_XXXX` _(use underscore `_`, not dash `-`)_
- **Table name**: `summaries` _(must be exactly this)_

_🧠 Pro Tip: Paste this in "Edit as text" mode for the schema:_

**Schema**:

```text
event_id:STRING,
time_uploaded:TIMESTAMP,
time_processed:TIMESTAMP,
document_path:STRING,
document_text:STRING,
document_summary:STRING
```

<details>
  <summary>Click to view</summary>
  
  1. <p>Go to <a href="https://console.cloud.google.com/bigquery" target="_blank">BigQuery</a></p>
  2. <p>Click on the three dots next to your project name</p>
  3. <p>Select "Create data set"</p>
  4. <p>Enter the dataset ID,  confirm the location, and click "Create dataset"</p>
  5. <p>Click on the dataset you just created in the left sidebar</p>
  6. <p>Click on "Create table"</p>
  7. <p>Select "Empty Table"</p>
  8. <p>Enter the table name in the "Table" field</p>
  9. <p>In the "Schema" section, select "Edit as text"</p>
  10. <p>Paste the schema provided above</p>
  11. <p>Click "Create table"</p>

</details>

---

### 10. Deploy the Cloud Function (Webhook) ☁️

#### Function Configuration

- **Function name**: `challenge-function-XXXX`
- **Runtime**: Python 3.12
- **Trigger**: EventArc
- **Trigger Name**: `challenge-trigger-XXXX`
- **Trigger Type**: Google Sources
- **Trigger Provider**: Cloud Storage
- **Event Type**: `google.cloud.storage.object.v1.finalized`
- **Bucket**: The main bucket
- **Service Account**: Use the Trigger Service Account _(⚠️ If prompted to grant Pub/Sub a role — click “Grant”)_

#### Container Configuration

- **Container Service Account**: Inside the Security tab, select the Webhook Service Account you created earlier (`challenge-webhook-sa-XXXX`).
- **Variables & Secrets**: Add the following environment variables:

| **Variable** | **Value** |
|---|---|
| PROJECT_ID | Will Be Provided During Session |
| LOCATION | us-central1 |
| OUTPUT_BUCKET | Your trigger bucket name |
| DOCAI_PROCESSOR | Will Be Provided During Session </br>projects/{NUMBER}/locations/us/processors/{ID} |
| DOCAI_LOCATION | us |
| BQ_DATASET | Your dataset name |
| BQ_TABLE | summaries |
| LOG_EXECUTION_ID | true |

<details>
  <summary>Click to view</summary>
  
  1. <p>Go to <a href="https://console.cloud.google.com/functions" target="_blank">Cloud Functions</a></p>
  2. <p>Click on "Write a function"</p>
  3. <p>Fill in the function (service) name, update the region and select the runtime</p>
  4. <p>Click on "Add trigger" and select "Other EventArc trigger"</p>
  5. <p>Set the trigger name to <code>challenge-trigger-XXXX</code></p>
  6. <p>Set the trigger type to Google Sources</p>
  7. <p>Set the trigger provider to Cloud Storage</p>
  8. <p>Set the event type to <code>google.cloud.storage.object.v1.finalized</code></p>
  9. <p>Select the main bucket you created earlier</p>
  10. <p>Under "Container", select "Container Image"</p>
  11. <p>Set the container service account to the webhook service account you created earlier. IF a prompt appears to grant <code>eventarc.eventReceiver</code> role, click "Grant"</p>
  12. <p>Click on "Save trigger"</p>
  13. <p>Scroll down to the "Containers, volumes, network,security" section and expand it</p>
  14. <p>Under "container" box, select "Variable & Secrets"</p>
  15. <p>Click on "Add variable"</p>
  16. <p>Enter the variable name and value as per the table above</p>
  17. <p>Click on "Add variable" for each variable</p>
  18. <p>Once all variables are added, click "Create"</p>

</details>

---

### 11. Update the Cloud Function Code ☁️

⚠️ **NOTE**: You need to change the function entry point to `on_cloud_event`

Update the `main.py` and `requirements.txt` with the ones here in the repository (Backend folder).

<details>
  <summary>Click to view</summary>
  
  1. <p>Copy the contents of <code>main.py</code> and <code>requirements.txt</code> from the repository</p>
  2. <p>Go back to the Cloud Function you created</p>
  3. <p>Paste the contents of <code>main.py</code> into the inline editor</p>
  4. <p>Paste the contents of <code>requirements.txt</code> into the inline editor
  5. Change the "Function entry point" to <code>on_cloud_event</code></p>
  6. <p>Click "Save and redeploy"</p>
  7. Wait for the deployment to finish (it may take a few minutes)</p>

</details>

---

### 12. Test and Check on BigQuery 📊

You can either use the script `scripts/start_frontend.sh` to start the frontend or upload a file directly to the main bucket.

#### Option 1: Upload a File to the Main Bucket 📂

1. Go to [Cloud Storage]("https://console.cloud.google.com/storage/browser")
2. Click on the main bucket you created earlier
3. Click on "Upload / Upload files"
4. Select a file to upload (maximum 5MB)
5. Go to [BigQuery]("https://console.cloud.google.com/bigquery)
6. Click on the dataset you created earlier
7. Click on the `summaries` table
8. Click on "Query"
9. Run the following query to see the results:

  ```sql
  SELECT * FROM `your_project_id.challenge_dataset_XXXX.summaries`
  ```

#### Option 2: Using the Frontend with Cloud Shell 🖥️

  ⚠️ **NOTE**: To use the script, you need to be authenticated. You can use on GCP Cloud Shell to be easy and fast.

1. Open Cloud Shell on top right corner of the GCP Console
2. Clone this repo and navigate to the `scripts` folder
3. Run the command `bash start_frontend.sh`
4. You will be asked the variables PROJECT_ID, BUCKET_NAME, DATASET_NAME and TABLE_NAME
5. Enter the values you used during the setup
6. Click on the web preview icon (looks like a monitor) in the Cloud Shell toolbar
7. Select "Preview on port 8080"
8. Open your browser and go to `http://localhost:8080`
9. Click on the "Choose File" button and select a file to upload (maximum 5MB)
10. Click on the "Upload" button
11. You will be able to see in a few seconds (sometimes takes a few more) the summary of the document

---

### Cheat Sheet 🃏

The `script/deploy.sh` file is a script that will deploy all the resources needed for the challenge. You can use it to deploy the resources in a single command.

<details>
  <summary>Click to view</summary>
  
  1. <p>Open a terminal</p>
  2. <p>Navigate to the <code>scripts</code> folder in the repository</p>
  3. <p>Run the command <code>bash deploy.sh -h</code> to see the help</p>

</details></p>

The `scripts/delete.sh` file is a script that will delete all the resources created for the challenge. You can use it to delete the resources in a single command.

<details>
  <summary>Click to view</summary>
  
  1. <p>Open a terminal</p>
  2. <p>Navigate to the <code>scripts</code> folder in the repository</p>
  3. <p>Run the command <code>bash delete.sh -h</code> to see the help</p>
  4. <p>Be aware that you must use the file that was generated during the deployment above</p>

</details>
