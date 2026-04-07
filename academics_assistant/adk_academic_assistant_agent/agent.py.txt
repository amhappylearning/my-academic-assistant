import os
import google.auth
import dotenv
from google.adk.agents import Agent
from google.adk.apps import App
from google.adk.models import Gemini
from google.adk.tools.google_search import GoogleSearch
from google.adk.tools.bigquery import BigQueryToolset, BigQueryCredentialsConfig
from google.adk.agents import LlmAgent
from google.adk.agents.llm_agent import Agent

import logging
import google.cloud.logging
from dotenv import load_dotenv

from google.adk.agents import SequentialAgent
from google.adk.tools.tool_context import ToolContext
from google.adk.tools.langchain_tool import LangchainTool


import google.auth
import google.auth.transport.requests
import google.oauth2.id_token

# --- Setup Logging and Environment ---

cloud_logging_client = google.cloud.logging.Client()
cloud_logging_client.setup_logging()

load_dotenv()

model_name = os.getenv("MODEL")

from toolbox_core import ToolboxSyncClient

toolbox = ToolboxSyncClient("http://127.0.0.1:5000")
dotenv.load_dotenv()

# Load all the tools
tools = toolbox.load_toolset('my_bq_toolset')
tools = toolbox.load_toolset('my_maps_toolset')

PROJECT_ID = os.getenv('GOOGLE_CLOUD_PROJECT', 'project_not_set')


# 1. Model Configuration
# Using the latest Gemini 3.1 Pro Preview for advanced reasoning
llm = Gemini(model_id="gemini-3.1-pro-preview")

# 2. Tool Setup
# Google Search for real-time academic trends
search_tool = [google-search]

#greeter
def prompt_saver(
    tool_context: ToolContext, prompt: str
) -> dict[str, str]:
    """Saves the user's initial prompt to the state."""
    tool_context.state["PROMPT"] = prompt
    logging.info(f"[State updated] Added to PROMPT: {prompt}")
    return {"status": "success"}

# 3. Sub-Agent: Summary Specialist
summary_agent = Agent(
    name="SummaryAgent",
    model=llm,
    description="Specializes in generating concise, structured summaries of academic data.",
    instruction="""
    You are a summarization expert. Your goal is to take raw data from BigQuery 
    (consultations and admin data) and search results to create high-level 
    academic reports. Focus on clarity, key performance indicators, and 
    trends for the current academic year.
    """
)

agent_workflow = SequentialAgent(
    name="agent_workflow",
    description="The main workflow for handling a user's request about academic session.",
    sub_agents=[summary_agent]     # Step 2: generate the summary and the final response
    
)

# 4. Root Agent: Academic Assistant
academic_assistant = LlmAgent(
    name="AcademicAssistant",
    model="gemini-3.1-pro-preview",
    description=(
        "Main interface for academic year oversight and consultation management."
    ),
   
    
    instruction=(f"""
    You are the Lead Academic Assistant. You have access to the 'admin-data' and 
    'consultations' tables in BigQuery.
    
    Your Workflow:
    1. Use the BigQuery tool to pull details regarding the school names, total_fees, year across country and state especially in United States from the 
       'consultations' and 'admin-data' tables present in administration schema.
    2. Use Google Search if the user asks for external academic benchmarks. Use intelligence to take best-decision for answeringa question.
    3. Delegate to the 'SummaryAgent' when a structured final report or 
       executive summary is needed.
  
                Help the user answer questions by strategically combining insights from below sources:
                
                1.  **BigQuery toolset:** Access academic session fees, schools, admission details (inc. consultations), admin_data, administration schema dataset. Do not use any other dataset.
                Run all query jobs from project id: my-chrt-apr-hck-project. 
                Use the BigQuery tool to pull details regarding the session, school names, total_fees, year across country and state especially in United States from the 
                'consultations' and 'admin-data' tables present in administration schema.

                2.  **Maps Toolset:** Use this for real-world location analysis, finding competition/places and calculating necessary travel routes.
                    Include a hyperlink to an interactive map in your response where appropriate.
                
                3. Use Google Search if the user asks for external academic benchmarks. Use intelligence to take best-decision for answeringa question.
                
                4. Delegate to the 'SummaryAgent' when a structured final report or 
       executive summary is needed.    
                """
                )  ,
    tools=tools,
    sub_agents= [prompt_save], [agent_workflow]
  )
