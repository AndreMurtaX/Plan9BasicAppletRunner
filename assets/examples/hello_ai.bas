' =============================================================================
' 01_hello_ai.bas - Your first AI integration
' =============================================================================
' The absolute minimum to call an AI and get a response.
' No GUI, no conversation history, just one question and one answer.
'
' TO RUN WITH OLLAMA (free, local, no API key):
'   1. Install Ollama from https://ollama.com
'   2. Run: ollama pull llama3.2
'   3. Run this program as-is
'
' TO RUN WITH A CLOUD PROVIDER:
'   Change PROVIDER$ and APIKEY$ below.
'   Providers: "anthropic", "openai", "groq", "deepseek", "mistral"
' =============================================================================
LET PROVIDER$ = "ollama"
LET APIKEY$   = ""
LET MODEL$    = "gemma3:4b"
' Create an AI client
LET ai# = ai_client#(PROVIDER$, APIKEY$)
LET ai# = ai_model#(ai#, MODEL$)
' Ask a question and print the answer
LET response$ = ai_complete$(ai#, "What is the meaning of life? Answer in one sentence.")
IF ai_ok(ai#) = 1 THEN
  PRINTLN response$
ELSE
  PRINTLN "Something went wrong: " + ai_errormsg$()
END IF
' Always free resources when done
LET x = ai_free(ai#)
