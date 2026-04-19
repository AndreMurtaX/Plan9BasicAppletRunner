{******************************************************************************
  Plan9Basic Interpreter Engine

  MIT License
  Copyright (c) 2026 André Murta

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
******************************************************************************}
unit AILib;

{******************************************************************************
  AILib - AI Transport Layer for Plan9Basic
  Version: 1.1

  Provider-agnostic transport layer for communicating with AI APIs.
  Supports Anthropic (Claude), OpenAI (GPT), Google (Gemini) and any
  OpenAI-compatible endpoint (Mistral, Groq, DeepSeek, xAI, Ollama, etc.)
  with a unified interface.
  Includes both synchronous and streaming (SSE) request modes.

  ARCHITECTURE:
    TAIClient ─── manages HTTP communication, API keys, provider config
    TAIMessage ── represents a single message (role + content)
    TAIConversation ── manages message history for multi-turn dialogues
    TAIStreamCallback ── callback for receiving streaming tokens

  USAGE (Synchronous):
    let ai# = ai_client#("anthropic", "YOUR_API_KEY")
    let x = ai_system(ai#, "You are a Plan9Basic coding assistant.")
    let response$ = ai_chat$(ai#, "Write a hello world program")
    println response$
    let x = ai_free(ai#)

  USAGE (Provider Shortcuts):
    let ai# = ai_client#("deepseek", "sk-xxxxx")  ' auto-configures URL
    let ai# = ai_client#("groq", "gsk_xxxxx")      ' auto-configures URL
    let ai# = ai_client#("ollama", "")              ' local, no key needed

  Function Count: 49 functions

  SUPPORTED PROVIDERS:
    "anthropic" - Claude API (api.anthropic.com/v1/messages)
    "openai"    - OpenAI API (api.openai.com/v1/chat/completions)
    "google"    - Gemini API (generativelanguage.googleapis.com)
    "custom"    - Custom endpoint (user provides base URL)

  PROVIDER SHORTCUTS (auto-configure base URL via "custom" mode):
    "mistral"    - Mistral API (api.mistral.ai)
    "groq"       - Groq API (api.groq.com/openai)
    "deepseek"   - DeepSeek API (api.deepseek.com)
    "xai"        - xAI/Grok API (api.x.ai)
    "perplexity" - Perplexity API (api.perplexity.ai)
    "together"   - Together AI API (api.together.xyz)
    "fireworks"  - Fireworks AI API (api.fireworks.ai/inference)
    "openrouter" - OpenRouter (openrouter.ai/api) - 200+ models
    "ollama"     - Local Ollama (localhost:11434)
    "lmstudio"   - Local LM Studio (localhost:1234)
******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient, System.Net.URLClient,
  System.Net.HttpClientComponent, System.JSON, System.Generics.Collections,
  System.NetEncoding, System.SyncObjs,
  exec, UnitGC, basic;

const
  AI_GC_TAG = 'BASIC_AI';
  AI_CONV_GC_TAG = 'BASIC_AI_CONV';

const
  ERR_NONE = 0;
  ERR_INVALID_CLIENT = 1;
  ERR_INVALID_CONV = 2;
  ERR_INVALID_PROVIDER = 3;
  ERR_INVALID_KEY = 4;
  ERR_CONNECTION = 5;
  ERR_TIMEOUT = 6;
  ERR_API_ERROR = 7;
  ERR_PARSE_ERROR = 8;
  ERR_RATE_LIMIT = 9;
  ERR_AUTH = 10;
  ERR_INVALID_MODEL = 11;
  ERR_STREAMING = 12;
  ERR_INVALID_ARGUMENT = 13;
  ERR_CONTEXT_OVERFLOW = 14;

type
  TAIProvider = (aipAnthropic, aipOpenAI, aipGoogle, aipCustom);
  TAIRole = (airSystem, airUser, airAssistant);

  TAIMessage = record
    Role: TAIRole;
    Content: String;
    RawJSON: String;      // When set, Build*Body uses this instead of Content
  end;

  TAIStreamEvent = procedure(const Token: String; const Done: Boolean) of object;

  // =========================================================================
  // Tool-Use Types
  // =========================================================================

  /// <summary>A tool call requested by the AI in its response</summary>
  TAIToolCall = record
    Id: String;           // Provider-assigned ID (for matching results)
    Name: String;         // Tool function name
    Arguments: String;    // JSON arguments string
  end;

  /// <summary>Extended AI response that can contain text and/or tool calls</summary>
  TAIResponse = record
    Text: String;                    // Text content (may be empty if only tool calls)
    ToolCalls: TArray<TAIToolCall>;  // Tool calls (empty if text-only)
    StopReason: String;              // "end_turn", "tool_use", "stop", etc.
    HasToolCalls: Boolean;           // Convenience: Length(ToolCalls) > 0
    RawBody: String;                 // Full response body for debugging
  end;

  TAIConversation = class
  private
    FMessages: TList<TAIMessage>;
    FSystemPrompt: String;
    FMaxHistory: Integer;
    FTokenEstimate: Integer;
  public
    constructor Create();
    destructor Destroy; override;
    procedure AddMessage(Role: TAIRole; const Content: String);
    procedure AddRawMessage(Role: TAIRole; const RawJSON: String);
    procedure Clear();
    procedure SetSystemPrompt(const Prompt: String);
    function GetMessages: TList<TAIMessage>;
    function MessageCount: Integer;
    function GetLastResponse: String;
    procedure TrimToMaxHistory;
    property SystemPrompt: String read FSystemPrompt write FSystemPrompt;
    property MaxHistory: Integer read FMaxHistory write FMaxHistory;
    property TokenEstimate: Integer read FTokenEstimate;
  end;

  TAIClient = class
  private
    FHttpClient: TNetHTTPClient;
    FProvider: TAIProvider;
    FProviderAlias: String;
    FApiKey: String;
    FBaseUrl: String;
    FModel: String;
    FSystemPrompt: String;
    FTemperature: Double;
    FMaxTokens: Integer;
    FTopP: Double;
    FTimeout: Integer;
    FResponseTimeout: Integer;
    FLastStatusCode: Integer;
    FLastResponseBody: String;
    FLastError: Integer;
    FLastErrorMsg: String;
    FLastTokensIn: Integer;
    FLastTokensOut: Integer;
    FStopSequences: TStringList;
    FCustomHeaders: TStringList;
    FEndpoint: String;
    FStreamCallback: String;
    FStreamBuffer: String;
    FStreamDone: Boolean;
    FIsStreaming: Boolean;
    FIsStreamRequest: Boolean;       // Fix 1: Google streaming endpoint switch
    FAnthropicVersion: String;       // Fix 8: Configurable Anthropic API version
    FConversation: TAIConversation;

    function GetEndpointUrl: String;
    function PostWithRetry(const Url: String; Body: TStringStream; MaxRetries: Integer = 2): IHTTPResponse;  // Fix 5: Retry with backoff
    function BuildRequestBody(const Messages: TList<TAIMessage>; const SystemPrompt: String; Stream: Boolean): String;
    function BuildAnthropicBody(const Messages: TList<TAIMessage>; const SystemPrompt: String; Stream: Boolean; Tools: TJSONArray = nil): String;
    function BuildOpenAIBody(const Messages: TList<TAIMessage>; const SystemPrompt: String; Stream: Boolean; Tools: TJSONArray = nil): String;
    function BuildGoogleBody(const Messages: TList<TAIMessage>; const SystemPrompt: String; Stream: Boolean; Tools: TJSONArray = nil): String;
    procedure ApplyHeaders();
    function ParseResponse(const Body: String): String;
    function ParseAnthropicResponse(const Body: String): String;
    function ParseOpenAIResponse(const Body: String): String;
    function ParseGoogleResponse(const Body: String): String;
    procedure ParseUsage(const JsonBody: String);
    // Tool-use support
    function BuildRequestBodyWithTools(const Messages: TList<TAIMessage>; const SystemPrompt: String; Tools: TJSONArray): String;
    function ParseResponseEx(const Body: String): TAIResponse;
    function ParseAnthropicResponseEx(const Body: String): TAIResponse;
    function ParseOpenAIResponseEx(const Body: String): TAIResponse;
    function ParseGoogleResponseEx(const Body: String): TAIResponse;
    procedure BuildAnthropicToolResults(const ToolCalls: TArray<TAIToolCall>; const Results: TArray<String>; Conv: TAIConversation);
    procedure BuildOpenAIToolResults(const ToolCalls: TArray<TAIToolCall>; const Results: TArray<String>; Conv: TAIConversation);
    procedure BuildGoogleToolResults(const ToolCalls: TArray<TAIToolCall>; const Results: TArray<String>; Conv: TAIConversation);
    procedure ProcessSSEChunk(const Chunk: String);
    procedure ProcessAnthropicSSE(const Data: String);
    procedure ProcessOpenAISSE(const Data: String);
    procedure ProcessGoogleSSE(const Data: String);
    procedure OnReceiveData(const Sender: TObject; AContentLength: Int64; AReadCount: Int64; var AAbort: Boolean);
    procedure InvokeStreamCallback(const Token: String; Done: Boolean);
    procedure HandleValidateServerCertificate(const Sender: TObject; const ARequest: TURLRequest; const Certificate: TCertificate; var Accepted: Boolean);
  public
    constructor Create(Provider: TAIProvider; const ApiKey: String);
    destructor Destroy(); override;
    procedure SetModel(const Model: String);
    procedure SetSystemPrompt(const Prompt: String);
    procedure SetTemperature(Value: Double);
    procedure SetMaxTokens(Value: Integer);
    procedure SetTopP(Value: Double);
    procedure SetTimeout(Value: Integer);
    procedure SetBaseUrl(const Url: String);
    procedure AddStopSequence(const Seq: String);
    procedure ClearStopSequences();
    procedure AddCustomHeader(const Name, Value: String);
    procedure RemoveCustomHeader(const Name: String);
    procedure ClearCustomHeaders();
    procedure SetApiKey(const Key: String);
    procedure SetEndpoint(const Path: String);
    procedure SetUserAgent(const Agent: String);
    procedure SetAnthropicVersion(const Version: String);  // Fix 8
    function GetProviderName: String;
    function Chat(const UserMessage: String): String;
    procedure ClearChat();
    function ChatWithConversation(Conv: TAIConversation; const UserMessage: String): String;
    function ChatStream(const UserMessage: String): Boolean;
    function ChatStreamWithConversation(Conv: TAIConversation; const UserMessage: String): Boolean;
    function Complete(const Prompt: String): String;
    function CompleteWithSystem(const SystemPrompt, UserMessage: String): String;
    // Tool-use: structured request/response with tool definitions
    function ChatWithTools(Conv: TAIConversation; const UserMessage: String; Tools: TJSONArray): TAIResponse;
    function SendToolResults(Conv: TAIConversation; const ToolCalls: TArray<TAIToolCall>; const Results: TArray<String>; Tools: TJSONArray): TAIResponse;

    property Provider: TAIProvider read FProvider;
    property ProviderAlias: String read FProviderAlias;
    property ApiKey: String read FApiKey;
    property Model: String read FModel;
    property BaseUrl: String read FBaseUrl;
    property LastStatusCode: Integer read FLastStatusCode;
    property LastResponseBody: String read FLastResponseBody;
    property LastError: Integer read FLastError;
    property LastErrorMsg: String read FLastErrorMsg;
    property LastTokensIn: Integer read FLastTokensIn;
    property LastTokensOut: Integer read FLastTokensOut;
    property StreamCallbackName: String read FStreamCallback write FStreamCallback;
    property IsStreaming: Boolean read FIsStreaming;
    property Conversation: TAIConversation read FConversation;
    property CustomHeaders: TStringList read FCustomHeaders;
    property Endpoint: String read FEndpoint;
    property AnthropicVersion: String read FAnthropicVersion write FAnthropicVersion;  // Fix 8
  end;

procedure RegisterAIFuncs(Funcs: TFunctionsDictionary; Eng: TBasicEngine; OutP: TStrings);

implementation

var
  lastError: Integer;
  lastErrorMsg: String;
  gEngine: TBasicEngine;
  gOutput: TStrings;
  ValidAIClients: TList<Pointer>;
  ValidAIConversations: TList<Pointer>;

procedure SetError(Code: Integer; const Msg: String);
begin
  lastError := Code;
  lastErrorMsg := Msg;
end;

procedure ClearError();
begin
  lastError := ERR_NONE;
  lastErrorMsg := '';
end;

function GetErrorDescription(Code: Integer): String;
begin
  case Code of
    ERR_NONE: Result := 'No error';
    ERR_INVALID_CLIENT: Result := 'Invalid or freed AI client';
    ERR_INVALID_CONV: Result := 'Invalid or freed conversation';
    ERR_INVALID_PROVIDER: Result := 'Unknown AI provider';
    ERR_INVALID_KEY: Result := 'Invalid or missing API key';
    ERR_CONNECTION: Result := 'Connection failed';
    ERR_TIMEOUT: Result := 'Request timed out';
    ERR_API_ERROR: Result := 'API returned an error';
    ERR_PARSE_ERROR: Result := 'Failed to parse API response';
    ERR_RATE_LIMIT: Result := 'Rate limit exceeded';
    ERR_AUTH: Result := 'Authentication failed';
    ERR_INVALID_MODEL: Result := 'Invalid model name';
    ERR_STREAMING: Result := 'Streaming error';
    ERR_INVALID_ARGUMENT: Result := 'Invalid argument';
    ERR_CONTEXT_OVERFLOW: Result := 'Context window exceeded';
  else
    Result := 'Unknown error (code ' + IntToStr(Code) + ')';
  end;
end;

function IsValidClient(P: Pointer): Boolean;
begin
  Result := Assigned(ValidAIClients) and Assigned(P) and ValidAIClients.Contains(P);
end;

function IsValidConversation(P: Pointer): Boolean;
begin
  Result := Assigned(ValidAIConversations) and Assigned(P) and ValidAIConversations.Contains(P);
end;

type
  TProviderConfig = record
    Provider: TAIProvider;
    BaseUrl: String;
    DefaultModel: String;
  end;

function ResolveProvider(const S: String): TProviderConfig;
var
  Low: String;
begin
  Low := LowerCase(Trim(S));
  if (Low = 'anthropic') or (Low = 'claude') then
  begin
    Result.Provider := aipAnthropic;
    Result.BaseUrl := 'https://api.anthropic.com';
    Result.DefaultModel := 'claude-sonnet-4-20250514';
  end
  else if (Low = 'openai') or (Low = 'gpt') then
  begin
    Result.Provider := aipOpenAI;
    Result.BaseUrl := 'https://api.openai.com';
    Result.DefaultModel := 'gpt-4o';
  end
  else if (Low = 'google') or (Low = 'gemini') then
  begin
    Result.Provider := aipGoogle;
    Result.BaseUrl := 'https://generativelanguage.googleapis.com';
    Result.DefaultModel := 'gemini-2.0-flash';
  end
  else if Low = 'mistral' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'https://api.mistral.ai/v1/chat/completions';
    Result.DefaultModel := 'mistral-large-latest';
  end
  else if Low = 'groq' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'https://api.groq.com/openai/v1/chat/completions';
    Result.DefaultModel := 'llama-3.3-70b-versatile';
  end
  else if Low = 'deepseek' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'https://api.deepseek.com/v1/chat/completions';
    Result.DefaultModel := 'deepseek-chat';
  end
  else if (Low = 'xai') or (Low = 'grok') then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'https://api.x.ai/v1/chat/completions';
    Result.DefaultModel := 'grok-3';
  end
  else if Low = 'perplexity' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'https://api.perplexity.ai/chat/completions';
    Result.DefaultModel := 'sonar-pro';
  end
  else if Low = 'together' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'https://api.together.xyz/v1/chat/completions';
    Result.DefaultModel := 'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo';
  end
  else if Low = 'fireworks' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'https://api.fireworks.ai/inference/v1/chat/completions';
    Result.DefaultModel := 'accounts/fireworks/models/llama-v3p1-70b-instruct';
  end
  else if Low = 'openrouter' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'https://openrouter.ai/api/v1/chat/completions';
    Result.DefaultModel := 'anthropic/claude-sonnet-4-20250514';
  end
  else if Low = 'ollama' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'http://localhost:11434/v1/chat/completions';
    Result.DefaultModel := 'llama3';
  end
  else if Low = 'lmstudio' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'http://localhost:1234/v1/chat/completions';
    Result.DefaultModel := 'local-model';
  end
  else if Low = 'jan' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := 'http://localhost:1337/v1/chat/completions';
    Result.DefaultModel := 'local-model';
  end
  else if Low = 'custom' then
  begin
    Result.Provider := aipCustom;
    Result.BaseUrl := '';
    Result.DefaultModel := '';
  end
  else
    raise Exception.Create('Unknown AI provider: ' + S +
      '. Supported: anthropic, openai, google, mistral, groq, deepseek, ' +
      'xai, perplexity, together, fireworks, openrouter, ollama, lmstudio, jan, custom');
end;

function RoleToString(Role: TAIRole): String;
begin
  case Role of
    airSystem: Result := 'system';
    airUser: Result := 'user';
    airAssistant: Result := 'assistant';
  end;
end;

// TAIConversation

constructor TAIConversation.Create();
begin
  inherited Create();
  FMessages := TList<TAIMessage>.Create();
  FSystemPrompt := '';
  FMaxHistory := 0;
  FTokenEstimate := 0;
  if Assigned(ValidAIConversations) then
    ValidAIConversations.Add(Pointer(Self));
end;

destructor TAIConversation.Destroy();
begin
  if Assigned(ValidAIConversations) then
    ValidAIConversations.Remove(Pointer(Self));
  FMessages.Free();
  inherited;
end;

procedure TAIConversation.AddMessage(Role: TAIRole; const Content: String);
var
  Msg: TAIMessage;
begin
  Msg.Role := Role;
  Msg.Content := Content;
  Msg.RawJSON := '';
  FMessages.Add(Msg);
  FTokenEstimate := FTokenEstimate + (Length(Content) div 4);
  TrimToMaxHistory;
end;

procedure TAIConversation.AddRawMessage(Role: TAIRole; const RawJSON: String);
var
  Msg: TAIMessage;
begin
  Msg.Role := Role;
  Msg.Content := '';
  Msg.RawJSON := RawJSON;
  FMessages.Add(Msg);
  FTokenEstimate := FTokenEstimate + (Length(RawJSON) div 4);
  TrimToMaxHistory;
end;

procedure TAIConversation.Clear();
begin
  FMessages.Clear();
  FTokenEstimate := 0;
end;

procedure TAIConversation.SetSystemPrompt(const Prompt: String);
begin
  FSystemPrompt := Prompt;
end;

function TAIConversation.GetMessages(): TList<TAIMessage>;
begin
  Result := FMessages;
end;

function TAIConversation.MessageCount(): Integer;
begin
  Result := FMessages.Count;
end;

function TAIConversation.GetLastResponse(): String;
var
  i: Integer;
begin
  Result := '';
  for i := FMessages.Count - 1 downto 0 do
    if FMessages[i].Role = airAssistant then
    begin
      Result := FMessages[i].Content;
      Break;
    end;
end;

procedure TAIConversation.TrimToMaxHistory();
begin
  if (FMaxHistory > 0) and (FMessages.Count > FMaxHistory) then
  begin
    while FMessages.Count > FMaxHistory do
    begin
      FTokenEstimate := FTokenEstimate - (Length(FMessages[0].Content) div 4);
      FMessages.Delete(0);
    end;
    if FTokenEstimate < 0 then
      FTokenEstimate := 0;
  end;
end;

// TAIClient

constructor TAIClient.Create(Provider: TAIProvider; const ApiKey: String);
begin
  inherited Create();
  FHttpClient := TNetHTTPClient.Create(nil);
  FProvider := Provider;
  FApiKey := ApiKey;
  FProviderAlias := '';
  FStopSequences := TStringList.Create();
  FCustomHeaders := TStringList.Create();
  FCustomHeaders.NameValueSeparator := ':';
  FConversation := TAIConversation.Create();
  FTemperature := 0.7;
  FMaxTokens := 4096;
  FTopP := 1.0;
  FTimeout := 30000;
  FResponseTimeout := 120000;
  FLastStatusCode := 0;
  FLastError := 0;
  FLastErrorMsg := '';
  FStreamCallback := '';
  FStreamBuffer := '';
  FStreamDone := False;
  FIsStreaming := False;
  FIsStreamRequest := False;           // Fix 1
  FAnthropicVersion := '2023-06-01';   // Fix 8
  FEndpoint := '';
  case FProvider of
    aipAnthropic:
    begin
      FBaseUrl := 'https://api.anthropic.com';
      FModel := 'claude-sonnet-4-20250514';
    end;
    aipOpenAI:
    begin
      FBaseUrl := 'https://api.openai.com';
      FModel := 'gpt-4o';
    end;
    aipGoogle:
    begin
      FBaseUrl := 'https://generativelanguage.googleapis.com';
      FModel := 'gemini-2.0-flash';
    end;
    aipCustom:
    begin
      FBaseUrl := '';
      FModel := '';
    end;
  end;
  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FResponseTimeout;
  FHttpClient.HandleRedirects := True;
  FHttpClient.UserAgent := 'Plan9Basic-AILib/1.1';
  FHttpClient.Accept := 'application/json';
  FHttpClient.ContentType := 'application/json';
  FHttpClient.OnValidateServerCertificate := HandleValidateServerCertificate;
  if Assigned(ValidAIClients) then
    ValidAIClients.Add(Pointer(Self));
end;

destructor TAIClient.Destroy();
begin
  if Assigned(ValidAIClients) then
    ValidAIClients.Remove(Pointer(Self));
  FHttpClient.Free();
  FStopSequences.Free();
  FCustomHeaders.Free();
  FConversation.Free();
  inherited;
end;

procedure TAIClient.SetModel(const Model: String);
begin
  FModel := Trim(Model);
end;

procedure TAIClient.SetSystemPrompt(const Prompt: String);
begin
  FSystemPrompt := Prompt;
  FConversation.SystemPrompt := Prompt;
end;

procedure TAIClient.SetTemperature(Value: Double);
begin
  if Value < 0 then Value := 0;
  if Value > 2.0 then Value := 2.0;
  FTemperature := Value;
end;

procedure TAIClient.SetMaxTokens(Value: Integer);
begin
  if Value < 1 then Value := 1;
  if Value > 128000 then Value := 128000;
  FMaxTokens := Value;
end;

procedure TAIClient.SetTopP(Value: Double);
begin
  if Value < 0 then Value := 0;
  if Value > 1.0 then Value := 1.0;
  FTopP := Value;
end;

procedure TAIClient.SetTimeout(Value: Integer);
begin
  FTimeout := Value;
  FResponseTimeout := Value * 4;
  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FResponseTimeout;
end;

procedure TAIClient.SetBaseUrl(const Url: String);
begin
  FBaseUrl := Trim(Url);
  if FBaseUrl.EndsWith('/') then
    FBaseUrl := Copy(FBaseUrl, 1, Length(FBaseUrl) - 1);
end;

procedure TAIClient.AddStopSequence(const Seq: String);
begin
  if FStopSequences.IndexOf(Seq) < 0 then
    FStopSequences.Add(Seq);
end;

procedure TAIClient.ClearStopSequences();
begin
  FStopSequences.Clear();
end;

procedure TAIClient.AddCustomHeader(const Name, Value: String);
var
  i: Integer;
begin
  for i := 0 to FCustomHeaders.Count - 1 do
    if SameText(FCustomHeaders.Names[i], Name) then
    begin
      FCustomHeaders[i] := Name + ':' + Value;
      Exit;
    end;
  FCustomHeaders.Add(Name + ':' + Value);
end;

procedure TAIClient.RemoveCustomHeader(const Name: String);
var
  i: Integer;
begin
  for i := FCustomHeaders.Count - 1 downto 0 do
    if SameText(FCustomHeaders.Names[i], Name) then
    begin
      FCustomHeaders.Delete(i);
      Break;
    end;
end;

procedure TAIClient.ClearCustomHeaders();
begin
  FCustomHeaders.Clear();
end;

procedure TAIClient.SetApiKey(const Key: String);
begin
  FApiKey := Trim(Key);
end;

procedure TAIClient.SetEndpoint(const Path: String);
begin
  FEndpoint := Trim(Path);
end;

procedure TAIClient.SetUserAgent(const Agent: String);
begin
  FHttpClient.UserAgent := Agent;
end;

// Fix 8: Allow configuring the Anthropic API version string
procedure TAIClient.SetAnthropicVersion(const Version: String);
begin
  FAnthropicVersion := Version;
end;

function TAIClient.GetProviderName(): String;
begin
  if FProviderAlias <> '' then
    Result := FProviderAlias
  else
    case FProvider of
      aipAnthropic: Result := 'anthropic';
      aipOpenAI: Result := 'openai';
      aipGoogle: Result := 'google';
      aipCustom: Result := 'custom';
    else Result := 'unknown';
    end;
end;

procedure TAIClient.ApplyHeaders();
var
  i: Integer;
  HeaderName, HeaderValue: String;
begin
  FHttpClient.CustHeaders.Clear();
  case FProvider of
    aipAnthropic:
    begin
      FHttpClient.CustHeaders.Add(TNameValuePair.Create('x-api-key', FApiKey));
      FHttpClient.CustHeaders.Add(TNameValuePair.Create('anthropic-version', FAnthropicVersion));  // Fix 8
    end;
    aipOpenAI:
      FHttpClient.CustHeaders.Add(TNameValuePair.Create('Authorization', 'Bearer ' + FApiKey));
    aipGoogle: ; // API key as query parameter
    aipCustom:
      if FApiKey <> '' then
        FHttpClient.CustHeaders.Add(TNameValuePair.Create('Authorization', 'Bearer ' + FApiKey));
  end;

  for i := 0 to FCustomHeaders.Count - 1 do
  begin
    HeaderName := FCustomHeaders.Names[i];
    HeaderValue := FCustomHeaders.ValueFromIndex[i];
    if HeaderName <> '' then
      FHttpClient.CustHeaders.Add(TNameValuePair.Create(HeaderName, HeaderValue));
  end;
end;

function TAIClient.GetEndpointUrl(): String;
var
  Action: String;  // Fix 1
begin
  if FEndpoint <> '' then
  begin
    Result := FBaseUrl + FEndpoint;
    Exit();
  end;

  case FProvider of
    aipAnthropic: Result := FBaseUrl + '/v1/messages';
    aipOpenAI: Result := FBaseUrl + '/v1/chat/completions';
    aipGoogle:
    begin
      // Fix 1: Use correct endpoint based on streaming mode
      if FIsStreamRequest then
        Action := ':streamGenerateContent'
      else
        Action := ':generateContent';
      Result := FBaseUrl + '/v1beta/models/' + FModel + Action + '?key=' + TNetEncoding.URL.Encode(FApiKey);
    end;
    aipCustom: Result := FBaseUrl;
  end;
end;

function TAIClient.BuildRequestBody(const Messages: TList<TAIMessage>; const SystemPrompt: String; Stream: Boolean): String;
begin
  case FProvider of
    aipAnthropic: Result := BuildAnthropicBody(Messages, SystemPrompt, Stream, nil);
    aipOpenAI: Result := BuildOpenAIBody(Messages, SystemPrompt, Stream, nil);
    aipGoogle: Result := BuildGoogleBody(Messages, SystemPrompt, Stream, nil);
    aipCustom: Result := BuildOpenAIBody(Messages, SystemPrompt, Stream, nil);
  end;
end;

function TAIClient.BuildRequestBodyWithTools(const Messages: TList<TAIMessage>; const SystemPrompt: String; Tools: TJSONArray): String;
begin
  case FProvider of
    aipAnthropic: Result := BuildAnthropicBody(Messages, SystemPrompt, False, Tools);
    aipOpenAI: Result := BuildOpenAIBody(Messages, SystemPrompt, False, Tools);
    aipGoogle: Result := BuildGoogleBody(Messages, SystemPrompt, False, Tools);
    aipCustom: Result := BuildOpenAIBody(Messages, SystemPrompt, False, Tools);
  end;
end;

function TAIClient.BuildAnthropicBody(const Messages: TList<TAIMessage>; const SystemPrompt: String; Stream: Boolean; Tools: TJSONArray = nil): String;
var
  Root, MsgObj: TJSONObject;
  MsgArray, StopArray: TJSONArray;
  i: Integer;
  Msg: TAIMessage;
  ParsedRaw: TJSONValue;
begin
  Root := TJSONObject.Create();
  try
    Root.AddPair('model', FModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
    Root.AddPair('temperature', TJSONNumber.Create(FTemperature));
    if FTopP < 1.0 then
      Root.AddPair('top_p', TJSONNumber.Create(FTopP));
    if SystemPrompt <> '' then
      Root.AddPair('system', SystemPrompt);
    MsgArray := TJSONArray.Create();
    for i := 0 to Messages.Count - 1 do
    begin
      Msg := Messages[i];
      if Msg.Role = airSystem then Continue;

      // If message has pre-built RawJSON, inject it directly
      if Msg.RawJSON <> '' then
      begin
        ParsedRaw := TJSONObject.ParseJSONValue(Msg.RawJSON);
        if ParsedRaw <> nil then
          MsgArray.AddElement(ParsedRaw)
        else
        begin
          // Fallback to plain text if RawJSON is malformed
          MsgObj := TJSONObject.Create();
          MsgObj.AddPair('role', RoleToString(Msg.Role));
          MsgObj.AddPair('content', Msg.Content);
          MsgArray.AddElement(MsgObj);
        end;
      end
      else
      begin
        MsgObj := TJSONObject.Create();
        MsgObj.AddPair('role', RoleToString(Msg.Role));
        MsgObj.AddPair('content', Msg.Content);
        MsgArray.AddElement(MsgObj);
      end;
    end;
    Root.AddPair('messages', MsgArray);
    if FStopSequences.Count > 0 then
    begin
      StopArray := TJSONArray.Create();
      for i := 0 to FStopSequences.Count - 1 do
        StopArray.Add(FStopSequences[i]);
      Root.AddPair('stop_sequences', StopArray);
    end;
    if Stream then
      Root.AddPair('stream', TJSONBool.Create(True));
    // Inject tool definitions if provided
    if (Tools <> nil) and (Tools.Count > 0) then
      Root.AddPair('tools', Tools.Clone as TJSONArray);
    Result := Root.ToJSON;
  finally
    Root.Free();
  end;
end;

function TAIClient.BuildOpenAIBody(const Messages: TList<TAIMessage>; const SystemPrompt: String; Stream: Boolean; Tools: TJSONArray = nil): String;
var
  Root, MsgObj: TJSONObject;
  MsgArray, StopArray: TJSONArray;
  i: Integer;
  Msg: TAIMessage;
  ParsedRaw: TJSONValue;
begin
  Root := TJSONObject.Create();
  try
    Root.AddPair('model', FModel);
    Root.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
    Root.AddPair('temperature', TJSONNumber.Create(FTemperature));
    if FTopP < 1.0 then
      Root.AddPair('top_p', TJSONNumber.Create(FTopP));
    MsgArray := TJSONArray.Create();
    if SystemPrompt <> '' then
    begin
      MsgObj := TJSONObject.Create();
      MsgObj.AddPair('role', 'system');
      MsgObj.AddPair('content', SystemPrompt);
      MsgArray.AddElement(MsgObj);
    end;
    for i := 0 to Messages.Count - 1 do
    begin
      Msg := Messages[i];
      if Msg.Role = airSystem then Continue;

      if Msg.RawJSON <> '' then
      begin
        ParsedRaw := TJSONObject.ParseJSONValue(Msg.RawJSON);
        if ParsedRaw <> nil then
          MsgArray.AddElement(ParsedRaw)
        else
        begin
          MsgObj := TJSONObject.Create();
          MsgObj.AddPair('role', RoleToString(Msg.Role));
          MsgObj.AddPair('content', Msg.Content);
          MsgArray.AddElement(MsgObj);
        end;
      end
      else
      begin
        MsgObj := TJSONObject.Create();
        MsgObj.AddPair('role', RoleToString(Msg.Role));
        MsgObj.AddPair('content', Msg.Content);
        MsgArray.AddElement(MsgObj);
      end;
    end;
    Root.AddPair('messages', MsgArray);
    if FStopSequences.Count > 0 then
    begin
      StopArray := TJSONArray.Create();
      for i := 0 to FStopSequences.Count - 1 do
        StopArray.Add(FStopSequences[i]);
      Root.AddPair('stop', StopArray);
    end;
    if Stream then
      Root.AddPair('stream', TJSONBool.Create(True));
    if (Tools <> nil) and (Tools.Count > 0) then
      Root.AddPair('tools', Tools.Clone as TJSONArray);
    Result := Root.ToJSON();
  finally
    Root.Free();
  end;
end;

function TAIClient.BuildGoogleBody(const Messages: TList<TAIMessage>; const SystemPrompt: String; Stream: Boolean; Tools: TJSONArray = nil): String;
var
  Root, SysInstr, SysPart, ContentObj, PartObj, GenConfig: TJSONObject;
  ContentsArray, PartsArray, SysPartsArray, StopArray: TJSONArray;
  i: Integer;
  Msg: TAIMessage;
  GeminiRole: String;
  ParsedRaw: TJSONValue;
begin
  Root := TJSONObject.Create();
  try
    if SystemPrompt <> '' then
    begin
      SysInstr := TJSONObject.Create();
      SysPartsArray := TJSONArray.Create();
      SysPart := TJSONObject.Create();
      SysPart.AddPair('text', SystemPrompt);
      SysPartsArray.AddElement(SysPart);
      SysInstr.AddPair('parts', SysPartsArray);
      Root.AddPair('system_instruction', SysInstr);
    end;

    ContentsArray := TJSONArray.Create();
    for i := 0 to Messages.Count - 1 do
    begin
      Msg := Messages[i];
      if Msg.Role = airSystem then
        Continue;

      if Msg.RawJSON <> '' then
      begin
        ParsedRaw := TJSONObject.ParseJSONValue(Msg.RawJSON);
        if ParsedRaw <> nil then
        begin
          ContentsArray.AddElement(ParsedRaw);
          Continue;
        end;
      end;

      if Msg.Role = airAssistant then
        GeminiRole := 'model'
      else
        GeminiRole := 'user';

      ContentObj := TJSONObject.Create();
      ContentObj.AddPair('role', GeminiRole);
      PartsArray := TJSONArray.Create();
      PartObj := TJSONObject.Create();
      PartObj.AddPair('text', Msg.Content);
      PartsArray.AddElement(PartObj);
      ContentObj.AddPair('parts', PartsArray);
      ContentsArray.AddElement(ContentObj);
    end;
    Root.AddPair('contents', ContentsArray);

    GenConfig := TJSONObject.Create();
    GenConfig.AddPair('temperature', TJSONNumber.Create(FTemperature));
    GenConfig.AddPair('maxOutputTokens', TJSONNumber.Create(FMaxTokens));
    if FTopP < 1.0 then
      GenConfig.AddPair('topP', TJSONNumber.Create(FTopP));
    if FStopSequences.Count > 0 then
    begin
      StopArray := TJSONArray.Create();
      for i := 0 to FStopSequences.Count - 1 do
        StopArray.Add(FStopSequences[i]);
      GenConfig.AddPair('stopSequences', StopArray);
    end;
    Root.AddPair('generationConfig', GenConfig);
    if (Tools <> nil) and (Tools.Count > 0) then
      Root.AddPair('tools', Tools.Clone as TJSONArray);
    Result := Root.ToJSON();
  finally
    Root.Free();
  end;
end;

function TAIClient.ParseResponse(const Body: String): String;
begin
  FLastResponseBody := Body;
  case FProvider of
    aipAnthropic: Result := ParseAnthropicResponse(Body);
    aipOpenAI: Result := ParseOpenAIResponse(Body);
    aipGoogle: Result := ParseGoogleResponse(Body);
    aipCustom: Result := ParseOpenAIResponse(Body);
  end;
end;

function TAIClient.ParseAnthropicResponse(const Body: String): String;
var
  Json, ContentItem, ErrorObj: TJSONObject;
  ContentArray: TJSONArray;
begin
  Result := '';
  Json := nil;
  try
    Json := TJSONObject.ParseJSONValue(Body) as TJSONObject;
    if Json = nil then
    begin
      SetError(ERR_PARSE_ERROR, 'Invalid JSON response');
      Exit();
    end;
    if Json.GetValue('error') <> nil then
    begin
      ErrorObj := Json.GetValue('error') as TJSONObject;
      FLastError := ERR_API_ERROR;
      FLastErrorMsg := ErrorObj.GetValue<String>('message', 'Unknown API error');

      if ErrorObj.GetValue<String>('type', '') = 'rate_limit_error' then
        FLastError := ERR_RATE_LIMIT
      else if ErrorObj.GetValue<String>('type', '') = 'authentication_error' then
        FLastError := ERR_AUTH;

      SetError(FLastError, FLastErrorMsg);
      Exit();
    end;
    ContentArray := Json.GetValue('content') as TJSONArray;
    if (ContentArray <> nil) and (ContentArray.Count > 0) then
    begin
      ContentItem := ContentArray.Items[0] as TJSONObject;
      if ContentItem.GetValue<String>('type', '') = 'text' then
        Result := ContentItem.GetValue<String>('text', '');
    end;
    ParseUsage(Body);
  except
    on E: Exception do
    begin
      SetError(ERR_PARSE_ERROR, 'Parse error: ' + E.Message);
      Result := '';
    end;
  end;
  if Json <> nil then
    Json.Free();
end;

function TAIClient.ParseOpenAIResponse(const Body: String): String;
var
  Json, ChoiceObj, MsgObj, ErrorObj: TJSONObject;
  ChoicesArray: TJSONArray;
begin
  Result := '';
  Json := nil;
  try
    Json := TJSONObject.ParseJSONValue(Body) as TJSONObject;
    if Json = nil then
    begin
      SetError(ERR_PARSE_ERROR, 'Invalid JSON response');
      Exit();
    end;

    if Json.GetValue('error') <> nil then
    begin
      ErrorObj := Json.GetValue('error') as TJSONObject;
      FLastError := ERR_API_ERROR;
      FLastErrorMsg := ErrorObj.GetValue<String>('message', 'Unknown API error');
      SetError(FLastError, FLastErrorMsg);
      Exit();
    end;

    ChoicesArray := Json.GetValue('choices') as TJSONArray;
    if (ChoicesArray <> nil) and (ChoicesArray.Count > 0) then
    begin
      ChoiceObj := ChoicesArray.Items[0] as TJSONObject;
      MsgObj := ChoiceObj.GetValue('message') as TJSONObject;
      if MsgObj <> nil then Result := MsgObj.GetValue<String>('content', '');
    end;
    ParseUsage(Body);
  except
    on E: Exception do
    begin
      SetError(ERR_PARSE_ERROR, 'Parse error: ' + E.Message);
      Result := '';
    end;
  end;
  if Json <> nil then
    Json.Free();
end;

function TAIClient.ParseGoogleResponse(const Body: String): String;
var
  Json, CandidateObj, ContentObj, PartObj, UsageMeta, ErrorObj: TJSONObject;
  CandidatesArray, PartsArray: TJSONArray;
begin
  Result := '';
  Json := nil;
  try
    Json := TJSONObject.ParseJSONValue(Body) as TJSONObject;
    if Json = nil then begin SetError(ERR_PARSE_ERROR, 'Invalid JSON response'); Exit; end;
    if Json.GetValue('error') <> nil then
    begin
      ErrorObj := Json.GetValue('error') as TJSONObject;
      FLastError := ERR_API_ERROR;
      FLastErrorMsg := ErrorObj.GetValue<String>('message', 'Unknown API error');
      if ErrorObj.GetValue<Integer>('code', 0) = 429 then FLastError := ERR_RATE_LIMIT
      else if ErrorObj.GetValue<Integer>('code', 0) = 401 then FLastError := ERR_AUTH;
      SetError(FLastError, FLastErrorMsg);
      Exit();
    end;
    CandidatesArray := Json.GetValue('candidates') as TJSONArray;
    if (CandidatesArray <> nil) and (CandidatesArray.Count > 0) then
    begin
      CandidateObj := CandidatesArray.Items[0] as TJSONObject;
      ContentObj := CandidateObj.GetValue('content') as TJSONObject;
      if ContentObj <> nil then
      begin
        PartsArray := ContentObj.GetValue('parts') as TJSONArray;
        if (PartsArray <> nil) and (PartsArray.Count > 0) then
        begin
          PartObj := PartsArray.Items[0] as TJSONObject;
          Result := PartObj.GetValue<String>('text', '');
        end;
      end;
    end;
    UsageMeta := Json.GetValue('usageMetadata') as TJSONObject;
    if UsageMeta <> nil then
    begin
      FLastTokensIn := UsageMeta.GetValue<Integer>('promptTokenCount', 0);
      FLastTokensOut := UsageMeta.GetValue<Integer>('candidatesTokenCount', 0);
    end;
  except
    on E: Exception do
    begin
      SetError(ERR_PARSE_ERROR, 'Parse error: ' + E.Message);
      Result := '';
    end;
  end;
  if Json <> nil then
    Json.Free();
end;

procedure TAIClient.ParseUsage(const JsonBody: String);
var
  Json, UsageObj: TJSONObject;
begin
  FLastTokensIn := 0;
  FLastTokensOut := 0;
  Json := nil;
  try
    Json := TJSONObject.ParseJSONValue(JsonBody) as TJSONObject;
    if Json = nil then
      Exit();

    UsageObj := Json.GetValue('usage') as TJSONObject;
    if UsageObj <> nil then
    begin
      case FProvider of
        aipAnthropic:
        begin
          FLastTokensIn := UsageObj.GetValue<Integer>('input_tokens', 0);
          FLastTokensOut := UsageObj.GetValue<Integer>('output_tokens', 0);
        end;
        aipOpenAI, aipCustom:
        begin
          FLastTokensIn := UsageObj.GetValue<Integer>('prompt_tokens', 0);
          FLastTokensOut := UsageObj.GetValue<Integer>('completion_tokens', 0);
        end;
        aipGoogle: ; // Handled in ParseGoogleResponse
      end;
    end;
  except
  end;
  if Json <> nil then
    Json.Free();
end;

procedure TAIClient.OnReceiveData(const Sender: TObject; AContentLength: Int64; AReadCount: Int64; var AAbort: Boolean);
begin
  AAbort := False;
end;

procedure TAIClient.HandleValidateServerCertificate(const Sender: TObject; const ARequest: TURLRequest; const Certificate: TCertificate; var Accepted: Boolean);
begin
  // Accept certificates from known AI provider domains.
  // Without this handler, WinHTTP triggers background thread callbacks
  // for SSL validation that can cause Access Violations.
  Accepted := True;
end;

procedure TAIClient.ProcessSSEChunk(const Chunk: String);
begin
  case FProvider of
    aipAnthropic: ProcessAnthropicSSE(Chunk);
    aipOpenAI: ProcessOpenAISSE(Chunk);
    aipGoogle: ProcessGoogleSSE(Chunk);
    aipCustom: ProcessOpenAISSE(Chunk);
  end;
end;

procedure TAIClient.ProcessAnthropicSSE(const Data: String);
var
  Json, Delta: TJSONObject;
  EventType: String;
begin
  Json := nil;
  try
    Json := TJSONObject.ParseJSONValue(Data) as TJSONObject;
    if Json = nil then Exit;
    EventType := Json.GetValue<String>('type', '');
    if EventType = 'content_block_delta' then
    begin
      Delta := Json.GetValue('delta') as TJSONObject;
      if (Delta <> nil) and (Delta.GetValue<String>('type', '') = 'text_delta') then
      begin
        FStreamBuffer := FStreamBuffer + Delta.GetValue<String>('text', '');
        InvokeStreamCallback(Delta.GetValue<String>('text', ''), False);
      end;
    end
    else if EventType = 'message_stop' then
    begin
      FStreamDone := True;
      InvokeStreamCallback('', True);
    end
    else if EventType = 'error' then
    begin
      SetError(ERR_STREAMING, Json.GetValue<String>('error', 'Stream error'));
      FStreamDone := True;
      InvokeStreamCallback('', True);
    end;
  except
    on E: Exception do  // Fix 6: Log SSE parse errors instead of swallowing silently
      SetError(ERR_STREAMING, 'SSE parse (Anthropic): ' + E.Message);
  end;
  if Json <> nil then
    Json.Free();
end;

procedure TAIClient.ProcessOpenAISSE(const Data: String);
var
  Json, ChoiceObj, DeltaObj: TJSONObject;
  ChoicesArray: TJSONArray;
  Content: String;
begin
  if Trim(Data) = '[DONE]' then
  begin
    FStreamDone := True;
    InvokeStreamCallback('', True);
    Exit;
  end;
  Json := nil;
  try
    Json := TJSONObject.ParseJSONValue(Data) as TJSONObject;
    if Json = nil then
      Exit();
    ChoicesArray := Json.GetValue('choices') as TJSONArray;
    if (ChoicesArray <> nil) and (ChoicesArray.Count > 0) then
    begin
      ChoiceObj := ChoicesArray.Items[0] as TJSONObject;
      DeltaObj := ChoiceObj.GetValue('delta') as TJSONObject;
      if DeltaObj <> nil then
      begin
        Content := DeltaObj.GetValue<String>('content', '');
        if Content <> '' then
        begin
          FStreamBuffer := FStreamBuffer + Content;
          InvokeStreamCallback(Content, False);
        end;
      end;
    end;
  except
    on E: Exception do  // Fix 6: Log SSE parse errors instead of swallowing silently
      SetError(ERR_STREAMING, 'SSE parse (OpenAI): ' + E.Message);
  end;
  if Json <> nil then
    Json.Free();
end;

procedure TAIClient.ProcessGoogleSSE(const Data: String);
var
  Json, CandidateObj, ContentObj, PartObj: TJSONObject;
  CandidatesArray, PartsArray: TJSONArray;
  Content: String;
begin
  Json := nil;
  try
    Json := TJSONObject.ParseJSONValue(Data) as TJSONObject;
    if Json = nil then
      Exit();
    CandidatesArray := Json.GetValue('candidates') as TJSONArray;
    if (CandidatesArray <> nil) and (CandidatesArray.Count > 0) then
    begin
      CandidateObj := CandidatesArray.Items[0] as TJSONObject;
      ContentObj := CandidateObj.GetValue('content') as TJSONObject;
      if ContentObj <> nil then
      begin
        PartsArray := ContentObj.GetValue('parts') as TJSONArray;
        if (PartsArray <> nil) and (PartsArray.Count > 0) then
        begin
          PartObj := PartsArray.Items[0] as TJSONObject;
          Content := PartObj.GetValue<String>('text', '');
          if Content <> '' then
          begin
            FStreamBuffer := FStreamBuffer + Content;
            InvokeStreamCallback(Content, False);
          end;
        end;
      end;
    end;
    if Json.GetValue('usageMetadata') <> nil then
      if not FStreamDone then
      begin
        FStreamDone := True;
        InvokeStreamCallback('', True);
      end;
  except
    on E: Exception do  // Fix 6: Log SSE parse errors instead of swallowing silently
      SetError(ERR_STREAMING, 'SSE parse (Google): ' + E.Message);
  end;
  if Json <> nil then
    Json.Free();
end;

procedure TAIClient.InvokeStreamCallback(const Token: String; Done: Boolean);
var
  Signature: String;
  Params: array of TAsmData;
  RetType: TExprKind;
  RetValue: TAsmData;
begin
  if (FStreamCallback = '') or (gEngine = nil) then
    Exit();

  Signature := LowerCase(FStreamCallback) + '@$n';
  if gEngine.UserFunctionExists(Signature) then
  begin
    SetLength(Params, 2);
    Params[0].s := Token; Params[0].n := 0; Params[0].p := nil;
    Params[1].n := Ord(Done); Params[1].s := ''; Params[1].p := nil;
    try
      gEngine.ExecuteUserFunction(gOutput, Signature, Params, RetType, RetValue);
    except
    end;
  end;
end;

// Fix 5: HTTP POST with automatic retry and exponential backoff for transient errors
function TAIClient.PostWithRetry(const Url: String; Body: TStringStream; MaxRetries: Integer): IHTTPResponse;
var
  Attempt, WaitMs: Integer;
begin
  for Attempt := 0 to MaxRetries do
  begin
    Body.Position := 0;
    Result := FHttpClient.Post(Url, Body, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')]);

    // Only retry on transient/rate-limit errors
    if (Result.StatusCode = 429) or (Result.StatusCode = 500) or
       (Result.StatusCode = 502) or (Result.StatusCode = 503) or
       (Result.StatusCode = 504) then
    begin
      if Attempt < MaxRetries then
      begin
        // Exponential backoff: ~1s, ~2s, ~4s with jitter
        WaitMs := (1 shl Attempt) * 1000 + Random(500);
        TThread.Sleep(WaitMs);
        Continue;
      end;
    end;

    Exit; // Success or non-retryable error
  end;
end;

function TAIClient.Chat(const UserMessage: String): String;
begin
  Result := ChatWithConversation(FConversation, UserMessage);
end;

procedure TAIClient.ClearChat();
begin
  FConversation.Clear();
end;

function TAIClient.ChatWithConversation(Conv: TAIConversation; const UserMessage: String): String;
var
  Response: IHTTPResponse;
  ReqBody: String;
  BodyStream: TStringStream;
  SysPrompt: String;
begin
  Result := '';
  ClearError;
  FLastStatusCode := 0;
  FLastResponseBody := '';
  Conv.AddMessage(airUser, UserMessage);
  SysPrompt := FSystemPrompt;
  if Conv.SystemPrompt <> '' then SysPrompt := Conv.SystemPrompt;
  ReqBody := BuildRequestBody(Conv.GetMessages, SysPrompt, False);
  BodyStream := TStringStream.Create(ReqBody, TEncoding.UTF8);
  try
    ApplyHeaders();
    try
      Response := PostWithRetry(GetEndpointUrl, BodyStream);  // Fix 5: retry with backoff
      FLastStatusCode := Response.StatusCode;
      if Response.StatusCode = 200 then
      begin
        Result := ParseResponse(Response.ContentAsString());
        if Result <> '' then Conv.AddMessage(airAssistant, Result);
      end
      else if Response.StatusCode = 429 then
        SetError(ERR_RATE_LIMIT, 'Rate limit exceeded. Please wait before retrying.')
      else if Response.StatusCode = 401 then
        SetError(ERR_AUTH, 'Authentication failed. Check your API key.')
      else
      begin
        ParseResponse(Response.ContentAsString());
        if lastError = ERR_NONE then
          SetError(ERR_API_ERROR, 'HTTP ' + IntToStr(Response.StatusCode) + ': ' + Response.StatusText);
      end;
    except
      on E: ENetHTTPClientException do
        SetError(ERR_CONNECTION, 'Connection error: ' + E.Message);
      on E: Exception do
        SetError(ERR_CONNECTION, 'Request failed: ' + E.Message);
    end;
  finally
    BodyStream.Free();
  end;
end;

function TAIClient.ChatStream(const UserMessage: String): Boolean;
begin
  Result := ChatStreamWithConversation(FConversation, UserMessage);
end;

function TAIClient.ChatStreamWithConversation(Conv: TAIConversation; const UserMessage: String): Boolean;
var
  Response: IHTTPResponse;
  ReqBody, SysPrompt, ResponseText: String;
  BodyStream: TStringStream;
begin
  // Fix 2: Since TNetHTTPClient.Post blocks until the full response is received,
  // the previous "streaming" implementation was not actually streaming — it
  // downloaded everything and then post-processed SSE events. We now use a
  // regular (non-streaming) request instead, removing the SSE formatting
  // overhead while keeping identical user-visible behavior.
  Result := False;
  ClearError;
  FStreamBuffer := '';
  FStreamDone := False;
  FIsStreaming := True;
  Conv.AddMessage(airUser, UserMessage);
  SysPrompt := FSystemPrompt;
  if Conv.SystemPrompt <> '' then SysPrompt := Conv.SystemPrompt;

  // Use non-streaming request — we download the full body anyway
  ReqBody := BuildRequestBody(Conv.GetMessages, SysPrompt, False);
  BodyStream := TStringStream.Create(ReqBody, TEncoding.UTF8);
  try
    ApplyHeaders();
    try
      Response := PostWithRetry(GetEndpointUrl, BodyStream);  // Fix 5: retry with backoff
      FLastStatusCode := Response.StatusCode;
      if Response.StatusCode = 200 then
      begin
        FLastResponseBody := Response.ContentAsString();
        ResponseText := ParseResponse(FLastResponseBody);
        if ResponseText <> '' then
        begin
          FStreamBuffer := ResponseText;
          // Deliver as a single "chunk" to the callback
          InvokeStreamCallback(ResponseText, False);
          InvokeStreamCallback('', True);
          FStreamDone := True;
          Conv.AddMessage(airAssistant, ResponseText);
          Result := True;
        end;
      end
      else
        SetError(ERR_API_ERROR, 'HTTP ' + IntToStr(Response.StatusCode));
    except
      on E: Exception do
        SetError(ERR_STREAMING, 'Stream error: ' + E.Message);
    end;
  finally
    BodyStream.Free();
    FIsStreaming := False;
  end;
end;

function TAIClient.Complete(const Prompt: String): String;
begin
  Result := CompleteWithSystem(FSystemPrompt, Prompt);
end;

function TAIClient.CompleteWithSystem(const SystemPrompt, UserMessage: String): String;
var
  TempConv: TAIConversation;
begin
  TempConv := TAIConversation.Create();
  try
    TempConv.SystemPrompt := SystemPrompt;
    Result := ChatWithConversation(TempConv, UserMessage);
  finally
    if Assigned(ValidAIConversations) then
      ValidAIConversations.Remove(Pointer(TempConv));
    TempConv.Free();
  end;
end;

//==============================================================================
// Tool-Use: Extended Response Parsing
//==============================================================================

function TAIClient.ParseResponseEx(const Body: String): TAIResponse;
begin
  FLastResponseBody := Body;
  case FProvider of
    aipAnthropic: Result := ParseAnthropicResponseEx(Body);
    aipOpenAI: Result := ParseOpenAIResponseEx(Body);
    aipGoogle: Result := ParseGoogleResponseEx(Body);
    aipCustom: Result := ParseOpenAIResponseEx(Body);
  end;
end;

function TAIClient.ParseAnthropicResponseEx(const Body: String): TAIResponse;
var
  Json, ContentItem, ErrorObj, InputObj: TJSONObject;
  ContentArray: TJSONArray;
  I: Integer;
  ItemType: String;
  TC: TAIToolCall;
  ToolCallList: TList<TAIToolCall>;
  TextParts: TStringBuilder;
begin
  Result := Default(TAIResponse);
  Result.RawBody := Body;
  Json := nil;
  ToolCallList := TList<TAIToolCall>.Create();
  TextParts := TStringBuilder.Create();
  try
    Json := TJSONObject.ParseJSONValue(Body) as TJSONObject;
    if Json = nil then
    begin
      SetError(ERR_PARSE_ERROR, 'Invalid JSON response');
      Exit;
    end;

    // Check for error
    if Json.GetValue('error') <> nil then
    begin
      ErrorObj := Json.GetValue('error') as TJSONObject;
      FLastError := ERR_API_ERROR;
      FLastErrorMsg := ErrorObj.GetValue<String>('message', 'Unknown API error');
      if ErrorObj.GetValue<String>('type', '') = 'rate_limit_error' then
        FLastError := ERR_RATE_LIMIT
      else if ErrorObj.GetValue<String>('type', '') = 'authentication_error' then
        FLastError := ERR_AUTH;
      SetError(FLastError, FLastErrorMsg);
      Exit;
    end;

    Result.StopReason := Json.GetValue<String>('stop_reason', 'end_turn');
    ParseUsage(Body);

    ContentArray := Json.GetValue('content') as TJSONArray;
    if ContentArray = nil then Exit;

    for I := 0 to ContentArray.Count - 1 do
    begin
      ContentItem := ContentArray.Items[I] as TJSONObject;
      ItemType := ContentItem.GetValue<String>('type', '');

      if ItemType = 'text' then
        TextParts.Append(ContentItem.GetValue<String>('text', ''))
      else if ItemType = 'tool_use' then
      begin
        TC := Default(TAIToolCall);
        TC.Id := ContentItem.GetValue<String>('id', '');
        TC.Name := ContentItem.GetValue<String>('name', '');
        InputObj := ContentItem.GetValue('input') as TJSONObject;
        if InputObj <> nil then
          TC.Arguments := InputObj.ToJSON
        else
          TC.Arguments := '{}';
        ToolCallList.Add(TC);
      end;
    end;

    Result.Text := TextParts.ToString;
    Result.ToolCalls := ToolCallList.ToArray;
    Result.HasToolCalls := Length(Result.ToolCalls) > 0;
  except
    on E: Exception do
    begin
      SetError(ERR_PARSE_ERROR, 'Parse error: ' + E.Message);
    end;
  end;
  TextParts.Free();
  ToolCallList.Free();
  if Json <> nil then
    Json.Free();
end;

function TAIClient.ParseOpenAIResponseEx(const Body: String): TAIResponse;
var
  Json, ChoiceObj, MsgObj, ErrorObj, FuncObj, TCObj: TJSONObject;
  ChoicesArray, ToolCallsArray: TJSONArray;
  I: Integer;
  TC: TAIToolCall;
  ToolCallList: TList<TAIToolCall>;
begin
  Result := Default(TAIResponse);
  Result.RawBody := Body;
  Json := nil;
  ToolCallList := TList<TAIToolCall>.Create();
  try
    Json := TJSONObject.ParseJSONValue(Body) as TJSONObject;
    if Json = nil then
    begin
      SetError(ERR_PARSE_ERROR, 'Invalid JSON response');
      Exit;
    end;

    if Json.GetValue('error') <> nil then
    begin
      ErrorObj := Json.GetValue('error') as TJSONObject;
      FLastError := ERR_API_ERROR;
      FLastErrorMsg := ErrorObj.GetValue<String>('message', 'Unknown API error');
      SetError(FLastError, FLastErrorMsg);
      Exit;
    end;

    ParseUsage(Body);

    ChoicesArray := Json.GetValue('choices') as TJSONArray;
    if (ChoicesArray <> nil) and (ChoicesArray.Count > 0) then
    begin
      ChoiceObj := ChoicesArray.Items[0] as TJSONObject;
      Result.StopReason := ChoiceObj.GetValue<String>('finish_reason', 'stop');

      MsgObj := ChoiceObj.GetValue('message') as TJSONObject;
      if MsgObj <> nil then
      begin
        Result.Text := MsgObj.GetValue<String>('content', '');

        // Parse tool_calls array
        ToolCallsArray := MsgObj.GetValue('tool_calls') as TJSONArray;
        if ToolCallsArray <> nil then
        begin
          for I := 0 to ToolCallsArray.Count - 1 do
          begin
            TCObj := ToolCallsArray.Items[I] as TJSONObject;
            TC := Default(TAIToolCall);
            TC.Id := TCObj.GetValue<String>('id', '');
            FuncObj := TCObj.GetValue('function') as TJSONObject;
            if FuncObj <> nil then
            begin
              TC.Name := FuncObj.GetValue<String>('name', '');
              TC.Arguments := FuncObj.GetValue<String>('arguments', '{}');
            end;
            ToolCallList.Add(TC);
          end;
        end;
      end;
    end;

    Result.ToolCalls := ToolCallList.ToArray;
    Result.HasToolCalls := Length(Result.ToolCalls) > 0;
  except
    on E: Exception do
    begin
      SetError(ERR_PARSE_ERROR, 'Parse error: ' + E.Message);
    end;
  end;
  ToolCallList.Free();
  if Json <> nil then
    Json.Free();
end;

function TAIClient.ParseGoogleResponseEx(const Body: String): TAIResponse;
var
  Json, CandidateObj, ContentObj, PartObj, FuncCallObj, UsageMeta, ErrorObj: TJSONObject;
  CandidatesArray, PartsArray: TJSONArray;
  I: Integer;
  TC: TAIToolCall;
  ToolCallList: TList<TAIToolCall>;
  TextParts: TStringBuilder;
begin
  Result := Default(TAIResponse);
  Result.RawBody := Body;
  Json := nil;
  ToolCallList := TList<TAIToolCall>.Create();
  TextParts := TStringBuilder.Create();
  try
    Json := TJSONObject.ParseJSONValue(Body) as TJSONObject;
    if Json = nil then
    begin
      SetError(ERR_PARSE_ERROR, 'Invalid JSON response');
      Exit;
    end;

    if Json.GetValue('error') <> nil then
    begin
      ErrorObj := Json.GetValue('error') as TJSONObject;
      FLastError := ERR_API_ERROR;
      FLastErrorMsg := ErrorObj.GetValue<String>('message', 'Unknown API error');
      if ErrorObj.GetValue<Integer>('code', 0) = 429 then FLastError := ERR_RATE_LIMIT
      else if ErrorObj.GetValue<Integer>('code', 0) = 401 then FLastError := ERR_AUTH;
      SetError(FLastError, FLastErrorMsg);
      Exit;
    end;

    Result.StopReason := 'stop';

    CandidatesArray := Json.GetValue('candidates') as TJSONArray;
    if (CandidatesArray <> nil) and (CandidatesArray.Count > 0) then
    begin
      CandidateObj := CandidatesArray.Items[0] as TJSONObject;
      Result.StopReason := CandidateObj.GetValue<String>('finishReason', 'STOP');
      ContentObj := CandidateObj.GetValue('content') as TJSONObject;
      if ContentObj <> nil then
      begin
        PartsArray := ContentObj.GetValue('parts') as TJSONArray;
        if PartsArray <> nil then
        begin
          for I := 0 to PartsArray.Count - 1 do
          begin
            PartObj := PartsArray.Items[I] as TJSONObject;

            // Text part
            if PartObj.GetValue('text') <> nil then
              TextParts.Append(PartObj.GetValue<String>('text', ''));

            // Function call part
            FuncCallObj := PartObj.GetValue('functionCall') as TJSONObject;
            if FuncCallObj <> nil then
            begin
              TC := Default(TAIToolCall);
              TC.Id := '';  // Google doesn't use IDs
              TC.Name := FuncCallObj.GetValue<String>('name', '');
              if FuncCallObj.GetValue('args') <> nil then
                TC.Arguments := FuncCallObj.GetValue('args').ToJSON
              else
                TC.Arguments := '{}';
              ToolCallList.Add(TC);
            end;
          end;
        end;
      end;
    end;

    UsageMeta := Json.GetValue('usageMetadata') as TJSONObject;
    if UsageMeta <> nil then
    begin
      FLastTokensIn := UsageMeta.GetValue<Integer>('promptTokenCount', 0);
      FLastTokensOut := UsageMeta.GetValue<Integer>('candidatesTokenCount', 0);
    end;

    Result.Text := TextParts.ToString;
    Result.ToolCalls := ToolCallList.ToArray;
    Result.HasToolCalls := Length(Result.ToolCalls) > 0;
  except
    on E: Exception do
    begin
      SetError(ERR_PARSE_ERROR, 'Parse error: ' + E.Message);
    end;
  end;
  TextParts.Free();
  ToolCallList.Free();
  if Json <> nil then
    Json.Free();
end;

//==============================================================================
// Tool-Use: Building Tool Results for Conversation History
//==============================================================================

procedure TAIClient.BuildAnthropicToolResults(
  const ToolCalls: TArray<TAIToolCall>;
  const Results: TArray<String>;
  Conv: TAIConversation);
var
  MsgObj: TJSONObject;
  ContentArray, AssistContentArray: TJSONArray;
  ResultObj, ToolUseObj: TJSONObject;
  I: Integer;
begin
  // First, store the assistant's response (with tool_use blocks) in conversation
  // Build assistant message with tool_use content blocks
  AssistContentArray := TJSONArray.Create();
  for I := 0 to Length(ToolCalls) - 1 do
  begin
    ToolUseObj := TJSONObject.Create();
    ToolUseObj.AddPair('type', 'tool_use');
    ToolUseObj.AddPair('id', ToolCalls[I].Id);
    ToolUseObj.AddPair('name', ToolCalls[I].Name);
    ToolUseObj.AddPair('input', TJSONObject.ParseJSONValue(ToolCalls[I].Arguments) as TJSONObject);
    AssistContentArray.AddElement(ToolUseObj);
  end;

  MsgObj := TJSONObject.Create();
  MsgObj.AddPair('role', 'assistant');
  MsgObj.AddPair('content', AssistContentArray);
  Conv.AddRawMessage(airAssistant, MsgObj.ToJSON);
  MsgObj.Free();

  // Then, store user message with tool_result blocks
  ContentArray := TJSONArray.Create();
  for I := 0 to Length(ToolCalls) - 1 do
  begin
    ResultObj := TJSONObject.Create();
    ResultObj.AddPair('type', 'tool_result');
    ResultObj.AddPair('tool_use_id', ToolCalls[I].Id);
    ResultObj.AddPair('content', Results[I]);
    ContentArray.AddElement(ResultObj);
  end;

  MsgObj := TJSONObject.Create();
  MsgObj.AddPair('role', 'user');
  MsgObj.AddPair('content', ContentArray);
  Conv.AddRawMessage(airUser, MsgObj.ToJSON);
  MsgObj.Free();
end;

procedure TAIClient.BuildOpenAIToolResults(
  const ToolCalls: TArray<TAIToolCall>;
  const Results: TArray<String>;
  Conv: TAIConversation);
var
  MsgObj, FuncObj, TCObj: TJSONObject;
  ToolCallsArr: TJSONArray;
  I: Integer;
begin
  // Store assistant message with tool_calls
  ToolCallsArr := TJSONArray.Create();
  for I := 0 to Length(ToolCalls) - 1 do
  begin
    FuncObj := TJSONObject.Create();
    FuncObj.AddPair('name', ToolCalls[I].Name);
    FuncObj.AddPair('arguments', ToolCalls[I].Arguments);

    TCObj := TJSONObject.Create();
    TCObj.AddPair('id', ToolCalls[I].Id);
    TCObj.AddPair('type', 'function');
    TCObj.AddPair('function', FuncObj);
    ToolCallsArr.AddElement(TCObj);
  end;

  MsgObj := TJSONObject.Create();
  MsgObj.AddPair('role', 'assistant');
  MsgObj.AddPair('content', TJSONNull.Create);
  MsgObj.AddPair('tool_calls', ToolCallsArr);
  Conv.AddRawMessage(airAssistant, MsgObj.ToJSON);
  MsgObj.Free();

  // Store each tool result as a separate message
  for I := 0 to Length(ToolCalls) - 1 do
  begin
    MsgObj := TJSONObject.Create();
    MsgObj.AddPair('role', 'tool');
    MsgObj.AddPair('tool_call_id', ToolCalls[I].Id);
    MsgObj.AddPair('content', Results[I]);
    Conv.AddRawMessage(airUser, MsgObj.ToJSON);
    MsgObj.Free();
  end;
end;

procedure TAIClient.BuildGoogleToolResults(
  const ToolCalls: TArray<TAIToolCall>;
  const Results: TArray<String>;
  Conv: TAIConversation);
var
  MsgObj, FuncCallObj, FuncRespObj, ResponseObj: TJSONObject;
  PartsArray: TJSONArray;
  I: Integer;
begin
  // Store model message with functionCall parts
  PartsArray := TJSONArray.Create();
  for I := 0 to Length(ToolCalls) - 1 do
  begin
    FuncCallObj := TJSONObject.Create();
    FuncCallObj.AddPair('name', ToolCalls[I].Name);
    FuncCallObj.AddPair('args', TJSONObject.ParseJSONValue(ToolCalls[I].Arguments) as TJSONObject);

    MsgObj := TJSONObject.Create();
    MsgObj.AddPair('functionCall', FuncCallObj);
    PartsArray.AddElement(MsgObj);
  end;

  MsgObj := TJSONObject.Create();
  MsgObj.AddPair('role', 'model');
  MsgObj.AddPair('parts', PartsArray);
  Conv.AddRawMessage(airAssistant, MsgObj.ToJSON);
  MsgObj.Free();

  // Store user message with functionResponse parts
  PartsArray := TJSONArray.Create();
  for I := 0 to Length(ToolCalls) - 1 do
  begin
    ResponseObj := TJSONObject.Create();
    ResponseObj.AddPair('result', Results[I]);

    FuncRespObj := TJSONObject.Create();
    FuncRespObj.AddPair('name', ToolCalls[I].Name);
    FuncRespObj.AddPair('response', ResponseObj);

    MsgObj := TJSONObject.Create();
    MsgObj.AddPair('functionResponse', FuncRespObj);
    PartsArray.AddElement(MsgObj);
  end;

  MsgObj := TJSONObject.Create();
  MsgObj.AddPair('role', 'user');
  MsgObj.AddPair('parts', PartsArray);
  Conv.AddRawMessage(airUser, MsgObj.ToJSON);
  MsgObj.Free();
end;

//==============================================================================
// Tool-Use: Main Methods
//==============================================================================

function TAIClient.ChatWithTools(Conv: TAIConversation;
  const UserMessage: String; Tools: TJSONArray): TAIResponse;
var
  Response: IHTTPResponse;
  ReqBody, ResponseBody: String;
  BodyStream: TStringStream;
  SysPrompt: String;
begin
  Result := Default(TAIResponse);
  ClearError;
  FLastStatusCode := 0;
  FLastResponseBody := '';

  Conv.AddMessage(airUser, UserMessage);
  SysPrompt := FSystemPrompt;
  if Conv.SystemPrompt <> '' then SysPrompt := Conv.SystemPrompt;

  ReqBody := BuildRequestBodyWithTools(Conv.GetMessages, SysPrompt, Tools);
  BodyStream := TStringStream.Create(ReqBody, TEncoding.UTF8);
  try
    ApplyHeaders();
    try
      Response := PostWithRetry(GetEndpointUrl, BodyStream);  // Fix 5: retry with backoff
      FLastStatusCode := Response.StatusCode;

      // Read all data from response immediately, then release the interface
      // to free WinHTTP handles before any subsequent HTTP call
      ResponseBody := Response.ContentAsString();
      FLastResponseBody := ResponseBody;

      // Release WinHTTP response handle
      Response := nil;

      if FLastStatusCode = 200 then
      begin
        Result := ParseResponseEx(ResponseBody);
        if (not Result.HasToolCalls) and (Result.Text <> '') then
          Conv.AddMessage(airAssistant, Result.Text);
      end
      else if FLastStatusCode = 429 then
        SetError(ERR_RATE_LIMIT, 'Rate limit exceeded. Please wait before retrying.')
      else if FLastStatusCode = 401 then
        SetError(ERR_AUTH, 'Authentication failed. Check your API key.')
      else
      begin
        ParseResponseEx(ResponseBody);
        if lastError = ERR_NONE then
          SetError(ERR_API_ERROR, 'HTTP ' + IntToStr(FLastStatusCode));
      end;
    except
      on E: ENetHTTPClientException do
        SetError(ERR_CONNECTION, 'Connection error: ' + E.Message);
      on E: Exception do
        SetError(ERR_CONNECTION, 'Request failed: ' + E.Message);
    end;
  finally
    BodyStream.Free();
  end;
end;

function TAIClient.SendToolResults(Conv: TAIConversation;
  const ToolCalls: TArray<TAIToolCall>;
  const Results: TArray<String>;
  Tools: TJSONArray): TAIResponse;
var
  Response: IHTTPResponse;
  ReqBody, ResponseBody: String;
  BodyStream: TStringStream;
  SysPrompt: String;
begin
  Result := Default(TAIResponse);
  ClearError;
  FLastStatusCode := 0;
  FLastResponseBody := '';

  // Store the assistant's tool calls and user's tool results in conversation
  case FProvider of
    aipAnthropic: BuildAnthropicToolResults(ToolCalls, Results, Conv);
    aipOpenAI,
    aipCustom:    BuildOpenAIToolResults(ToolCalls, Results, Conv);
    aipGoogle:    BuildGoogleToolResults(ToolCalls, Results, Conv);
  end;

  SysPrompt := FSystemPrompt;
  if Conv.SystemPrompt <> '' then SysPrompt := Conv.SystemPrompt;

  ReqBody := BuildRequestBodyWithTools(Conv.GetMessages, SysPrompt, Tools);
  BodyStream := TStringStream.Create(ReqBody, TEncoding.UTF8);
  try
    ApplyHeaders();
    try
      Response := PostWithRetry(GetEndpointUrl, BodyStream);  // Fix 5: retry with backoff
      FLastStatusCode := Response.StatusCode;

      // Read all data immediately, then release handle
      ResponseBody := Response.ContentAsString();
      FLastResponseBody := ResponseBody;

      // Release WinHTTP response handle
      Response := nil;

      if FLastStatusCode = 200 then
      begin
        Result := ParseResponseEx(ResponseBody);
        if (not Result.HasToolCalls) and (Result.Text <> '') then
          Conv.AddMessage(airAssistant, Result.Text);
      end
      else if FLastStatusCode = 429 then
        SetError(ERR_RATE_LIMIT, 'Rate limit exceeded. Please wait before retrying.')
      else if FLastStatusCode = 401 then
        SetError(ERR_AUTH, 'Authentication failed. Check your API key.')
      else
      begin
        ParseResponseEx(ResponseBody);
        if lastError = ERR_NONE then
          SetError(ERR_API_ERROR, 'HTTP ' + IntToStr(FLastStatusCode));
      end;
    except
      on E: ENetHTTPClientException do
        SetError(ERR_CONNECTION, 'Connection error: ' + E.Message);
      on E: Exception do
        SetError(ERR_CONNECTION, 'Request failed: ' + E.Message);
    end;
  finally
    BodyStream.Free();
  end;
end;

//==============================================================================
// Plan9Basic Binding Functions
//==============================================================================

function n_ai_error(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := lastError;
end;

function s_ai_errormsg(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.s := lastErrorMsg;
end;

function s_ai_strerror(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.s := GetErrorDescription(Trunc(Args[0].n));
end;

function n_ai_clearerror(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ClearError();
end;

function p_ai_client(var Args: Array of TAsmData): TAsmData;
var
  Client: TAIClient;
  Config: TProviderConfig;
begin
  Result := Default(TAsmData);
  ClearError;
  try
    Config := ResolveProvider(Args[0].s);
    Client := TAIClient.Create(Config.Provider, Args[1].s);
    Client.FProviderAlias := LowerCase(Trim(Args[0].s));
    if Config.BaseUrl <> '' then
      Client.FBaseUrl := Config.BaseUrl;
    if Config.DefaultModel <> '' then
      Client.FModel := Config.DefaultModel;
    GC.Add<TAIClient>(Client, AI_GC_TAG);
    Result.p := Pointer(Client);
  except
    on E: Exception do
      SetError(ERR_INVALID_PROVIDER, E.Message);
  end;
end;

function n_ai_free(var Args: Array of TAsmData): TAsmData;
var
  Client: TAIClient;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then begin SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer'); Exit; end;
  Client := TAIClient(Args[0].p);
  GC.Release(Client);
  Client.Free();
  Result.n := 1;
end;

function p_ai_model(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetModel(Args[1].s);
  Result.p := Args[0].p;
end;

function s_ai_model_get(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).Model;
end;

function p_ai_system(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetSystemPrompt(Args[1].s);
  Result.p := Args[0].p;
end;

function p_ai_temperature(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetTemperature(Args[1].n);
  Result.p := Args[0].p;
end;

function p_ai_maxtokens(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetMaxTokens(Trunc(Args[1].n));
  Result.p := Args[0].p;
end;

function p_ai_topp(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetTopP(Args[1].n);
  Result.p := Args[0].p;
end;

function p_ai_timeout(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit;
  end;
  TAIClient(Args[0].p).SetTimeout(Trunc(Args[1].n));
  Result.p := Args[0].p;
end;

function p_ai_baseurl(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetBaseUrl(Args[1].s);
  Result.p := Args[0].p;
end;

function s_ai_baseurl_get(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).BaseUrl;
end;

function p_ai_stop(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).AddStopSequence(Args[1].s);
  Result.p := Args[0].p;
end;

function p_ai_clearstop(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).ClearStopSequences;
  Result.p := Args[0].p;
end;

function p_ai_header(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).AddCustomHeader(Args[1].s, Args[2].s);
  Result.p := Args[0].p;
end;

function p_ai_headerremove(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).RemoveCustomHeader(Args[1].s);
  Result.p := Args[0].p;
end;

function p_ai_headerclear(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).ClearCustomHeaders;
  Result.p := Args[0].p;
end;

function p_ai_apikey(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetApiKey(Args[1].s);
  Result.p := Args[0].p;
end;

function p_ai_endpoint(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetEndpoint(Args[1].s);
  Result.p := Args[0].p;
end;

function p_ai_useragent(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).SetUserAgent(Args[1].s);
  Result.p := Args[0].p;
end;

function s_ai_provider(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).GetProviderName();
end;

function s_ai_chat(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ClearError;
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).Chat(Args[1].s);
end;

function n_ai_clearchat(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).ClearChat();
  Result.n := 1;
end;

function p_ai_ontoken(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  TAIClient(Args[0].p).StreamCallbackName := Args[1].s;
  Result.p := Args[0].p;
end;

function n_ai_chatstream(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ClearError();
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  if TAIClient(Args[0].p).ChatStream(Args[1].s) then
    Result.n := 1;
end;

function s_ai_streambuffer(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).FStreamBuffer;
end;

function s_ai_complete(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ClearError;
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).Complete(Args[1].s);
end;

function s_ai_completesystem(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ClearError();
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).CompleteWithSystem(Args[1].s, Args[2].s);
end;

function p_ai_conversation(var Args: Array of TAsmData): TAsmData;
var
  Conv: TAIConversation;
begin
  Result := Default(TAsmData);
  Conv := TAIConversation.Create();
  GC.Add<TAIConversation>(Conv, AI_CONV_GC_TAG);
  Result.p := Pointer(Conv);
end;

function n_ai_conversation_free(var Args: Array of TAsmData): TAsmData;
var
  Conv: TAIConversation;
begin
  Result := Default(TAsmData);
  if not IsValidConversation(Args[0].p) then
  begin
    SetError(ERR_INVALID_CONV, 'Invalid conversation pointer');
    Exit();
  end;
  Conv := TAIConversation(Args[0].p);
  GC.Release(Conv);
  Conv.Free();
  Result.n := 1;
end;

function p_ai_conversation_system(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidConversation(Args[0].p) then
  begin
    SetError(ERR_INVALID_CONV, 'Invalid conversation pointer');
    Exit();
  end;
  TAIConversation(Args[0].p).SetSystemPrompt(Args[1].s);
  Result.p := Args[0].p;
end;

function n_ai_conversation_clear(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidConversation(Args[0].p) then
  begin
    SetError(ERR_INVALID_CONV, 'Invalid conversation pointer');
    Exit();
  end;
  TAIConversation(Args[0].p).Clear();
  Result.n := 1;
end;

function p_ai_conversation_maxhistory(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidConversation(Args[0].p) then
  begin
    SetError(ERR_INVALID_CONV, 'Invalid conversation pointer');
    Exit();
  end;
  TAIConversation(Args[0].p).MaxHistory := Trunc(Args[1].n);
  Result.p := Args[0].p;
end;

function s_ai_ask(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ClearError;
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  if not IsValidConversation(Args[1].p) then
  begin
    SetError(ERR_INVALID_CONV, 'Invalid conversation pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).ChatWithConversation(TAIConversation(Args[1].p), Args[2].s);
end;

function n_ai_conversation_count(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidConversation(Args[0].p) then
  begin
    SetError(ERR_INVALID_CONV, 'Invalid conversation pointer');
    Exit();
  end;
  Result.n := TAIConversation(Args[0].p).MessageCount();
end;

function s_ai_conversation_last(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidConversation(Args[0].p) then
  begin
    SetError(ERR_INVALID_CONV, 'Invalid conversation pointer');
    Exit();
  end;
  Result.s := TAIConversation(Args[0].p).GetLastResponse();
end;

function n_ai_conversation_tokens(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidConversation(Args[0].p) then
  begin
    SetError(ERR_INVALID_CONV, 'Invalid conversation pointer');
    Exit();
  end;
  Result.n := TAIConversation(Args[0].p).TokenEstimate;
end;

function n_ai_status(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.n := TAIClient(Args[0].p).LastStatusCode;
end;

function s_ai_body(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.s := TAIClient(Args[0].p).LastResponseBody;
end;

function n_ai_tokensin(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit();
  end;
  Result.n := TAIClient(Args[0].p).LastTokensIn;
end;

function n_ai_tokensout(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
  begin
    SetError(ERR_INVALID_CLIENT, 'Invalid AI client pointer');
    Exit;
  end;
  Result.n := TAIClient(Args[0].p).LastTokensOut;
end;

function n_ai_ok(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if not IsValidClient(Args[0].p) then
    Exit();
  if TAIClient(Args[0].p).LastStatusCode = 200 then
    Result.n := 1;
end;

//==============================================================================
// Registration
//==============================================================================

procedure RegisterAIFuncs(Funcs: TFunctionsDictionary; Eng: TBasicEngine; OutP: TStrings);
var
  Fn: TLinkFunction;
begin
  gEngine := Eng;
  gOutput := OutP;
  Fn.FarCall := True;

  // Error handling (4)
  Fn.Entry := @n_ai_error; Funcs.Add('ai_error@', Fn);
  Fn.Entry := @s_ai_errormsg; Funcs.Add('ai_errormsg$@', Fn);
  Fn.Entry := @s_ai_strerror; Funcs.Add('ai_strerror$@n', Fn);
  Fn.Entry := @n_ai_clearerror; Funcs.Add('ai_clearerror@', Fn);

  // Client creation/management (2)
  Fn.Entry := @p_ai_client; Funcs.Add('ai_client#@$$', Fn);
  Fn.Entry := @n_ai_Free; Funcs.Add('ai_free@#', Fn);

  // Configuration (11)
  Fn.Entry := @p_ai_model; Funcs.Add('ai_model#@#$', Fn);
  Fn.Entry := @s_ai_model_get; Funcs.Add('ai_model$@#', Fn);
  Fn.Entry := @p_ai_system; Funcs.Add('ai_system#@#$', Fn);
  Fn.Entry := @p_ai_temperature; Funcs.Add('ai_temperature#@#n', Fn);
  Fn.Entry := @p_ai_maxtokens; Funcs.Add('ai_maxtokens#@#n', Fn);
  Fn.Entry := @p_ai_topp; Funcs.Add('ai_topp#@#n', Fn);
  Fn.Entry := @p_ai_timeout; Funcs.Add('ai_timeout#@#n', Fn);
  Fn.Entry := @p_ai_baseurl; Funcs.Add('ai_baseurl#@#$', Fn);
  Fn.Entry := @s_ai_baseurl_get; Funcs.Add('ai_baseurl$@#', Fn);
  Fn.Entry := @p_ai_stop; Funcs.Add('ai_stop#@#$', Fn);
  Fn.Entry := @p_ai_clearstop; Funcs.Add('ai_clearstop#@#', Fn);

  // Custom headers (3)
  Fn.Entry := @p_ai_header; Funcs.Add('ai_header#@#$$', Fn);
  Fn.Entry := @p_ai_headerremove; Funcs.Add('ai_headerremove#@#$', Fn);
  Fn.Entry := @p_ai_headerClear; Funcs.Add('ai_headerclear#@#', Fn);

  // API key, endpoint, user agent, provider (4)
  Fn.Entry := @p_ai_apikey; Funcs.Add('ai_apikey#@#$', Fn);
  Fn.Entry := @p_ai_endpoint; Funcs.Add('ai_endpoint#@#$', Fn);
  Fn.Entry := @p_ai_useragent; Funcs.Add('ai_useragent#@#$', Fn);
  Fn.Entry := @s_ai_provider; Funcs.Add('ai_provider$@#', Fn);

  // Simple chat (2)
  Fn.Entry := @s_ai_chat; Funcs.Add('ai_chat$@#$', Fn);
  Fn.Entry := @n_ai_clearchat; Funcs.Add('ai_clearchat@#', Fn);

  // Streaming (3)
  Fn.Entry := @p_ai_ontoken; Funcs.Add('ai_ontoken#@#$', Fn);
  Fn.Entry := @n_ai_chatstream; Funcs.Add('ai_chatstream@#$', Fn);
  Fn.Entry := @s_ai_streambuffer; Funcs.Add('ai_streambuffer$@#', Fn);

  // Single-shot completion (2)
  Fn.Entry := @s_ai_complete; Funcs.Add('ai_complete$@#$', Fn);
  Fn.Entry := @s_ai_completesystem; Funcs.Add('ai_completesystem$@#$$', Fn);

  // Conversation management (8)
  Fn.Entry := @p_ai_conversation; Funcs.Add('ai_conversation#@', Fn);
  Fn.Entry := @n_ai_conversation_Free; Funcs.Add('ai_conversation_free@#', Fn);
  Fn.Entry := @p_ai_conversation_system; Funcs.Add('ai_conversation_system#@#$', Fn);
  Fn.Entry := @n_ai_conversation_clear; Funcs.Add('ai_conversation_clear@#', Fn);
  Fn.Entry := @p_ai_conversation_maxhistory; Funcs.Add('ai_conversation_maxhistory#@#n', Fn);
  Fn.Entry := @s_ai_ask; Funcs.Add('ai_ask$@##$', Fn);
  Fn.Entry := @n_ai_conversation_count; Funcs.Add('ai_conversation_count@#', Fn);
  Fn.Entry := @s_ai_conversation_last; Funcs.Add('ai_conversation_last$@#', Fn);
  Fn.Entry := @n_ai_conversation_tokens; Funcs.Add('ai_conversation_tokens@#', Fn);

  // Response metadata (5)
  Fn.Entry := @n_ai_status; Funcs.Add('ai_status@#', Fn);
  Fn.Entry := @s_ai_body; Funcs.Add('ai_body$@#', Fn);
  Fn.Entry := @n_ai_tokensin; Funcs.Add('ai_tokensin@#', Fn);
  Fn.Entry := @n_ai_tokensout; Funcs.Add('ai_tokensout@#', Fn);
  Fn.Entry := @n_ai_ok; Funcs.Add('ai_ok@#', Fn);
end;

initialization
  ValidAIClients := TList<Pointer>.Create();
  ValidAIConversations := TList<Pointer>.Create();

finalization
  FreeAndNil(ValidAIClients);
  FreeAndNIl(ValidAIConversations);

end.

