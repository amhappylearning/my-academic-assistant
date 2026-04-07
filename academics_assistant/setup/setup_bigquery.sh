#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)
DATASET_NAME="administration"
LOCATION="US"

# Generate bucket name if not provided
if [ -z "$1" ]; then
    BUCKET_NAME="gs://mcp-academic-assistant-$PROJECT_ID"
    echo "No bucket provided. Using default: $BUCKET_NAME"
else
    BUCKET_NAME=$1
fi

echo "----------------------------------------------------------------"
echo "MCP Academics Assistant Demo Setup"
echo "Project: $PROJECT_ID"
echo "Dataset: $DATASET_NAME"
echo "Bucket:  $BUCKET_NAME"
echo "----------------------------------------------------------------"

# 1. Create Bucket if it doesn't exist
echo "[1/7] Checking bucket $BUCKET_NAME..."
if gcloud storage buckets describe $BUCKET_NAME >/dev/null 2>&1; then
    echo "      Bucket already exists."
else
    echo "      Creating bucket $BUCKET_NAME..."
    gcloud storage buckets create $BUCKET_NAME --location=$LOCATION
fi

# 2. Upload Data
echo "[2/7] Uploading data to $BUCKET_NAME..."
gcloud storage cp data/*.csv $BUCKET_NAME

# 3. Create Dataset
echo "[3/7] Creating Dataset '$DATASET_NAME'..."
if bq show "$PROJECT_ID:$DATASET_NAME" >/dev/null 2>&1; then
    echo "      Dataset already exists. Skipping creation."
else    
    bq mk --location=$LOCATION --dataset \
        --description "$DATASET_DESCRIPTION" \
        "$PROJECT_ID:$DATASET_NAME"
    echo "      Dataset created."
fi

# 4. Create Demographics Table
echo "[4/7] Setting up Table: demographics..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.admin_data\` (
  COUNTRY_NAME STRING NOT NULL,	
  COUNTRY_CODE STRING NOT NULL,	STATE_NAME STRING NOT NULL,	STATE_CD STRING NOT NULL,	REGION STRING NOT NULL,	
  SCHOOL_NAME STRING NOT NULL ,	TOTAL_BRANCHES STRING NOT NULL,	CLASS_NUMBER STRING NOT NULL,	CLASS_NAME STRING NOT NULL,	
  EXAM_BOARD STRING NOT NULL,	ADMISSION_FEES STRING NOT NULL,	UNIFORM_FEES STRING NOT NULL,	STATIONARY_FEES STRING NOT NULL,	
  ACADEMIC_FEES STRING NOT NULL,	ACTIVITY_FEES STRING NOT NULL,	EXAM_FEES STRING NOT NULL,	
  TOTAL_FEES STRING NOT NULL,	LATE_FEE STRING NOT NULL,	LATE_ADMISSION STRING NOT NULL,	MISCELLANEOUS_CHARGES STRING NOT NULL
)
OPTIONS(
    description='Academic Fee Details for schools across US, CAD, AUS,UK, IND .'
);"

bq load --source_format=CSV --skip_leading_rows=1 --ignore_unknown_values=true --replace \
    "$PROJECT_ID:$DATASET_NAME.admin_data" "$BUCKET_NAME/admin_data.csv"

# 5. Create Consultations Table
echo "[5/7] Setting up Table: consultations..."
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE \`$PROJECT_ID.$DATASET_NAME.consultations\` (
COUNTRY_NAME STRING,	
COUNTRY_CD STRING	,
STATE_NAME STRING	,
STATE_CD STRING	,
SCHOOL_NAME STRING	,
TOTAL_BRANCHES STRING	,
SESSION_START_DATE DATE	,
SESSION_END_DATE DATE	,
ANNUAL_DAY DATE	,
ACTVITY_SUMMARY STRING,	
QUARTERLY_MEETING_Q1 DATE	,
QUATERLY_MEETING_Q2 DATE	,
QUATERLY_MEETING_Q3 DATE	,
QUATERLY_MEETING_Q4 DATE,
SUMMER_HOLIDAYS STRING NOT NULL,
WINTER_HOLIDAYS STRING NOT NULL)
OPTIONS(
    description='Contains details regarding the academic calendar, holidays and important dates for schools across United States.'
);"

bq load --source_format=CSV --skip_leading_rows=1 --replace \
    "$PROJECT_ID:$DATASET_NAME.consultations" "$BUCKET_NAME/consultations.csv"

echo "----------------------------------------------------------------"
echo "Setup Complete!"
echo "----------------------------------------------------------------"
