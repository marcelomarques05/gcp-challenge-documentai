# GCP Document AI Challenge

## ℹ️ INFORMATION

- ✅ **Services are already enabled on the project**
- 📍 **All resources must be in the same REGION/LOCATION**
- 🌍 **Location Suggestion**: `us-central1`
- 🌍 **Region Suggestion**: `us`

---

## 🛠️ Step-by-Step Instructions

### 1. Access GCP Console  
Go to [https://console.cloud.google.com](https://console.cloud.google.com)

---

### 2. Select the Challenge Project  
_It will be informed during the session_

---

### 3. Create 2 Buckets (One for the Function and one for EventArc) 🪣

**Name suggestions**:  
- `challenge-main-XXXX`  
- `challenge-trigger-XXXX`  

_(Replace `XXXX` with your 4-letter code)_

---

### 4. Create a Docker Repository in Artifact Registry 🐳 

**Name suggestion**:  
- `challenge-repo-XXXX`

---

### 5. Create 2 Service Accounts (one for the Function and one for EventArc 🧑‍💻 

**Name suggestions**:  
- `challenge-webhook-sa-XXXX`  
- `challenge-trigger-sa-XXXX`

---

### 6. Assign Roles to Webhook/Function Service Account 🔐

Grant these roles:

- `roles/aiplatform.serviceAgent`
- `roles/bigquery.dataEditor`
- `roles/documentai.admin`

---

### 7. Assign Roles to Trigger/EventArc Service Account 🔐

Grant these roles:

- `roles/eventarc.eventReceiver`
- `roles/run.invoker`

---

### 8. Assign Role to Google Storage Service Account 🔐

1. Go to **Cloud Storage** → **Settings**
2. Copy the **GCS Service Account**
3. Grant the role:

- `roles/pubsub.publisher`  
  _(Ignore the “Outdated” message)_

---

### 9. Create BigQuery Dataset and Table 📊 

- **Dataset name**: `challenge_dataset_XXXX` _(use underscore `_`, not dash `-`)_
- **Table name**: `summaries` _(must be exactly this)_

_🧠 Pro Tip: Paste this in "Edit as text" mode for the schema:_

**Schema**:
```text
event_id:STRING  
time_uploaded:TIMESTAMP  
time_processed:TIMESTAMP  
document_path:STRING  
document_text:STRING  
document_summary:STRING
```

### 10. Deploy the Cloud Function (Webhook) ☁️

-	**Name**: `challenge-function-XXXX`
-	**Runtime**: Python 3.12
- **Trigger (via EventArc)**:

  * **Name**: `challenge-trigger-XXXX`

  * **Type**: Google Sources

  * **Provider**: Cloud Storage

  * **Event Type**: `google.cloud.storage.object.v1.finalized`

  * **Bucket**: Select the trigger bucket you created (challenge-trigger-XXXX)

  * **Service Account**: Use the Trigger Service Account _(⚠️ If prompted to grant Pub/Sub a role — click “Grant”)_
- **Environment Variables**

| **Variable** | **Value** |
|---|---| 
| PROJECT_ID | Will Be Provided During Session |
| LOCATION | us-central1 |
| OUTPUT_BUCKET | Your main bucket name |
| DOCAI_PROCESSOR | Will Be Provided During Session |
| DOCAI_LOCATION | us |
| BQ_DATASET | Your dataset name |
| BQ_TABLE | summaries |
| LOG_EXECUTION_ID | true |

### 11. Update the Cloud Function ☁️

⚠️ **NOTE**: You need to change the function entry point to `on_cloud_event`

Update the `main.py` and `requirements.txt` with the ones here in the repository.

Save and Redeploy


### 12. Check on BigQuery 📊

Go to the Bigquery table (summaries) and check if the information is there.

⚠️ **NOTE**: Depending on the size of the file, it can take some time. You can check in the GCP logging service the status.

### Cheat Sheet 🃏

The `deploy.sh` file contains all the gcloud commands used on this challenge. Note that you need to change the environment variables to yours before run. This can be executed on Cloud Shell 
