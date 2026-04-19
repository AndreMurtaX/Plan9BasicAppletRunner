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
unit RAGLib;

{******************************************************************************
  RAGLib - RAG Engine Library for Plan9Basic
  Version: 1.0.0

  Provides Plan9Basic binding functions for the RAG Engine, enabling BASIC
  programs and the built-in AI prompt terminal to query the knowledge base.

  Function Count: 13 functions

  CROSS-PLATFORM SUPPORT:
  =======================
  - Windows (Win32/Win64)
  - macOS (Intel/ARM)
  - Linux
  - Android
  - iOS

  FUNCTIONS:
  ==========

  === Engine Lifecycle ===
  rag#(path$)                    → Create RAG engine from knowledge base path
  rag_free(rag#)                 → Free RAG engine resources
  rag_rebuild#(rag#)             → Rebuild index from source documents

  === Core Retrieval ===
  rag_retrieve$(rag#, query$)           → Retrieve docs for query (returns combined content)
  rag_retrieve_json$(rag#, query$)      → Retrieve docs as JSON array with scores
  rag_retrieve_budget$(rag#, query$, n) → Retrieve with custom token budget

  === Direct Lookup ===
  rag_doc$(rag#, id$)            → Get full content of a specific document
  rag_functions$(rag#, query$)   → Find documents by function names
  rag_tags$(rag#, tags$)         → Find documents by tags (comma-separated)

  === Query Analysis ===
  rag_analyze$(rag#, query$)     → Analyze query and return intent/keywords as JSON

  === Information ===
  rag_count(rag#)                → Number of indexed documents
  rag_funccount(rag#)            → Number of indexed functions
  rag_summary$(rag#)             → Index summary string

  USAGE PATTERN:
  ==============
    let rag# = rag#("knowledge/")
    let docs$ = rag_retrieve$(rag#, "create a form with buttons")
    println docs$

    ' Use with AILib for complete AI pipeline:
    let system$ = "You are a Plan9Basic expert." + chr$(10) + docs$
    let code$ = ai_completesystem$(ai#, system$, "create a calculator")

    let x = rag_free(rag#)

  GC TAG: BASIC_RAG
******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  exec, UnitGC, UnitUtils, RAGEngine;

const
  RAG_GC_TAG = 'BASIC_RAG';

procedure RegisterRAGFuncs(Lib: TFunctionsDictionary);

implementation

{ ============================================================================
  VALIDATION
  ============================================================================ }

function ValidateRAG(P: Pointer; const FuncName: String): Boolean;
begin
  Result := (P <> nil) and (TObject(P) is TRAGEngine);
  if not Result then
    raise Exception.CreateFmt('%s: invalid RAG engine handle', [FuncName]);
end;

{ ============================================================================
  ENGINE LIFECYCLE
  ============================================================================ }

// rag#(path$) — Create RAG engine and load index
function p_rag_create(var Args: array of TAsmData): TAsmData;
var
  RAG: TRAGEngine;
  ResolvedPath: String;
begin
  Result := Default(TAsmData);

  if Length(Args) < 1 then
    raise Exception.Create('rag# requires knowledge base path');

  // Resolve path (on mobile, relative paths are mapped under GetDocumentsPath)
  ResolvedPath := TUtils.ResolveDataPath(Args[0].s);

  RAG := TRAGEngine.Create(ResolvedPath);
  RAG.LoadIndex;

  if Assigned(UnitGC.GC) then
    UnitGC.GC.Add<TRAGEngine>(RAG, RAG_GC_TAG);

  Result.p := RAG;
end;

// rag_free(rag#) — Free RAG engine
function n_rag_free(var Args: array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);

  if (Args[0].p <> nil) and (TObject(Args[0].p) is TRAGEngine) then
  begin
    if Assigned(UnitGC.GC) then
      UnitGC.GC.Release(Args[0].p);
    TRAGEngine(Args[0].p).Free();
    Result.n := 1;
  end;
end;

// rag_rebuild#(rag#) — Rebuild index from source files
function p_rag_rebuild(var Args: array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ValidateRAG(Args[0].p, 'rag_rebuild#');

  TRAGEngine(Args[0].p).BuildIndex;
  Result.p := Args[0].p;
end;

{ ============================================================================
  CORE RETRIEVAL
  ============================================================================ }

// rag_retrieve$(rag#, query$) — Retrieve combined content for prompt injection
function s_rag_retrieve(var Args: array of TAsmData): TAsmData;
var
  RAG: TRAGEngine;
  Results: TRAGResultList;
  SB: TStringBuilder;
begin
  Result := Default(TAsmData);

  if Length(Args) < 2 then
    raise Exception.Create('rag_retrieve$ requires RAG engine and query');

  ValidateRAG(Args[0].p, 'rag_retrieve$');
  RAG := TRAGEngine(Args[0].p);

  Results := RAG.Retrieve(Args[1].s);

  SB := TStringBuilder.Create();
  try
    for var R in Results do
    begin
      if SB.Length > 0 then
        SB.AppendLine.AppendLine;

      SB.AppendFormat('### %s', [R.Document.Title]).AppendLine;
      SB.Append(R.ContentForPrompt);

      if R.Truncated then
        SB.AppendLine.Append('(truncated)');
    end;

    Result.s := SB.ToString;
  finally
    SB.Free();
  end;
end;

// rag_retrieve_json$(rag#, query$) — Retrieve as JSON with scores
function s_rag_retrieve_json(var Args: array of TAsmData): TAsmData;
var
  RAG: TRAGEngine;
  Results: TRAGResultList;
  JsonArr: TJSONArray;
  JsonObj: TJSONObject;
begin
  Result := Default(TAsmData);

  if Length(Args) < 2 then
    raise Exception.Create('rag_retrieve_json$ requires RAG engine and query');

  ValidateRAG(Args[0].p, 'rag_retrieve_json$');
  RAG := TRAGEngine(Args[0].p);

  Results := RAG.Retrieve(Args[1].s);

  JsonArr := TJSONArray.Create();
  try
    for var R in Results do
    begin
      JsonObj := TJSONObject.Create();
      JsonObj.AddPair('id', R.Document.Id);
      JsonObj.AddPair('title', R.Document.Title);
      JsonObj.AddPair('category', R.Document.Category);
      JsonObj.AddPair('score', TJSONNumber.Create(R.Score));
      JsonObj.AddPair('tokens', TJSONNumber.Create(R.TokensUsed));
      JsonObj.AddPair('truncated', TJSONBool.Create(R.Truncated));
      JsonObj.AddPair('reasons', R.MatchReasons);
      JsonObj.AddPair('content', R.ContentForPrompt);
      JsonArr.AddElement(JsonObj);
    end;

    Result.s := JsonArr.ToString;
  finally
    JsonArr.Free();
  end;
end;

// rag_retrieve_budget$(rag#, query$, max_tokens) — Retrieve with custom budget
function s_rag_retrieve_budget(var Args: array of TAsmData): TAsmData;
var
  RAG: TRAGEngine;
  Results: TRAGResultList;
  SB: TStringBuilder;
  Budget: Integer;
begin
  Result := Default(TAsmData);

  if Length(Args) < 3 then
    raise Exception.Create('rag_retrieve_budget$ requires RAG engine, query, and token budget');

  ValidateRAG(Args[0].p, 'rag_retrieve_budget$');
  RAG := TRAGEngine(Args[0].p);
  Budget := Trunc(Args[2].n);

  Results := RAG.Retrieve(Args[1].s, Budget);

  SB := TStringBuilder.Create();
  try
    for var R in Results do
    begin
      if SB.Length > 0 then
        SB.AppendLine.AppendLine;
      SB.AppendFormat('### %s', [R.Document.Title]).AppendLine;
      SB.Append(R.ContentForPrompt);
    end;
    Result.s := SB.ToString;
  finally
    SB.Free();
  end;
end;

{ ============================================================================
  DIRECT LOOKUP
  ============================================================================ }

// rag_doc$(rag#, id$) — Get document by ID
function s_rag_doc(var Args: array of TAsmData): TAsmData;
var
  Doc: TRAGDocument;
begin
  Result := Default(TAsmData);

  if Length(Args) < 2 then
    raise Exception.Create('rag_doc$ requires RAG engine and document ID');

  ValidateRAG(Args[0].p, 'rag_doc$');

  try
    Doc := TRAGEngine(Args[0].p).GetDocument(Args[1].s);
    Result.s := Doc.Content;
  except
    on E: Exception do
      Result.s := 'Error: ' + E.Message;
  end;
end;

// rag_functions$(rag#, functions$) — Lookup by function names (comma-separated)
function s_rag_functions(var Args: array of TAsmData): TAsmData;
var
  RAG: TRAGEngine;
  FuncNames: TArray<String>;
  Results: TRAGResultList;
  SB: TStringBuilder;
begin
  Result := Default(TAsmData);

  if Length(Args) < 2 then
    raise Exception.Create('rag_functions$ requires RAG engine and function names');

  ValidateRAG(Args[0].p, 'rag_functions$');
  RAG := TRAGEngine(Args[0].p);

  FuncNames := Args[1].s.Split([',', ' '], TStringSplitOptions.ExcludeEmpty);
  Results := RAG.RetrieveByFunctions(FuncNames);

  SB := TStringBuilder.Create();
  try
    for var R in Results do
    begin
      if SB.Length > 0 then
        SB.AppendLine.AppendLine;
      SB.AppendFormat('### %s', [R.Document.Title]).AppendLine;
      SB.Append(R.ContentForPrompt);
    end;
    Result.s := SB.ToString;
  finally
    SB.Free();
  end;
end;

// rag_tags$(rag#, tags$) — Lookup by tags (comma-separated)
function s_rag_tags(var Args: array of TAsmData): TAsmData;
var
  RAG: TRAGEngine;
  Tags: TArray<String>;
  Results: TRAGResultList;
  SB: TStringBuilder;
begin
  Result := Default(TAsmData);

  if Length(Args) < 2 then
    raise Exception.Create('rag_tags$ requires RAG engine and tags');

  ValidateRAG(Args[0].p, 'rag_tags$');
  RAG := TRAGEngine(Args[0].p);

  Tags := Args[1].s.Split([','], TStringSplitOptions.ExcludeEmpty);
  Results := RAG.RetrieveByTags(Tags);

  SB := TStringBuilder.Create();
  try
    for var R in Results do
    begin
      if SB.Length > 0 then
        SB.AppendLine.AppendLine;
      SB.AppendFormat('### %s (score: %.1f)', [R.Document.Title, R.Score]).AppendLine;
      SB.Append(R.ContentForPrompt);
    end;
    Result.s := SB.ToString;
  finally
    SB.Free();
  end;
end;

{ ============================================================================
  QUERY ANALYSIS
  ============================================================================ }

// rag_analyze$(rag#, query$) — Return intent/keywords as JSON
function s_rag_analyze(var Args: array of TAsmData): TAsmData;
var
  RAG: TRAGEngine;
  Analysis: TRAGQueryAnalysis;
  JsonObj: TJSONObject;
  KWArr, FNArr, HintArr: TJSONArray;
begin
  Result := Default(TAsmData);

  if Length(Args) < 2 then
    raise Exception.Create('rag_analyze$ requires RAG engine and query');

  ValidateRAG(Args[0].p, 'rag_analyze$');
  RAG := TRAGEngine(Args[0].p);

  Analysis := RAG.Analyze(Args[1].s);

  JsonObj := TJSONObject.Create();
  try
    JsonObj.AddPair('query', Analysis.OriginalQuery);
    JsonObj.AddPair('intent', Analysis.Intent);
    JsonObj.AddPair('is_followup', TJSONBool.Create(Analysis.IsFollowUp));

    KWArr := TJSONArray.Create();
    for var KW in Analysis.Keywords do
      KWArr.Add(KW);
    JsonObj.AddPair('keywords', KWArr);

    FNArr := TJSONArray.Create();
    for var FN in Analysis.FunctionNames do
      FNArr.Add(FN);
    JsonObj.AddPair('function_names', FNArr);

    HintArr := TJSONArray.Create();
    for var H in Analysis.LibraryHints do
      HintArr.Add(H);
    JsonObj.AddPair('library_hints', HintArr);

    Result.s := JsonObj.ToString;
  finally
    JsonObj.Free();
  end;
end;

{ ============================================================================
  INFORMATION
  ============================================================================ }

// rag_count(rag#) — Document count
function n_rag_count(var Args: array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ValidateRAG(Args[0].p, 'rag_count');
  Result.n := TRAGEngine(Args[0].p).DocumentCount;
end;

// rag_funccount(rag#) — Function count
function n_rag_funccount(var Args: array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ValidateRAG(Args[0].p, 'rag_funccount');
  Result.n := TRAGEngine(Args[0].p).FunctionCount;
end;

// rag_summary$(rag#) — Index summary
function s_rag_summary(var Args: array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  ValidateRAG(Args[0].p, 'rag_summary$');
  Result.s := TRAGEngine(Args[0].p).GetIndexSummary;
end;

{ ============================================================================
  REGISTRATION
  ============================================================================ }

procedure RegisterRAGFuncs(Lib: TFunctionsDictionary);
var
  Fn: TLinkFunction;
begin
  Fn := Default(TLinkFunction);
  Fn.FarCall := True;

  // Engine lifecycle
  Fn.Entry := @p_rag_Create; Lib.Add('rag#@$', Fn);
  Fn.Entry := @n_rag_Free; Lib.Add('rag_free@#', Fn);
  Fn.Entry := @p_rag_rebuild; Lib.Add('rag_rebuild#@#', Fn);

  // Core retrieval
  Fn.Entry := @s_rag_retrieve; Lib.Add('rag_retrieve$@#$', Fn);
  Fn.Entry := @s_rag_retrieve_json; Lib.Add('rag_retrieve_json$@#$', Fn);
  Fn.Entry := @s_rag_retrieve_budget; Lib.Add('rag_retrieve_budget$@#$n', Fn);

  // Direct lookup
  Fn.Entry := @s_rag_doc; Lib.Add('rag_doc$@#$', Fn);
  Fn.Entry := @s_rag_functions; Lib.Add('rag_functions$@#$', Fn);
  Fn.Entry := @s_rag_tags; Lib.Add('rag_tags$@#$', Fn);

  // Query analysis
  Fn.Entry := @s_rag_analyze; Lib.Add('rag_analyze$@#$', Fn);

  // Information
  Fn.Entry := @n_rag_count; Lib.Add('rag_count@#', Fn);
  Fn.Entry := @n_rag_funccount; Lib.Add('rag_funccount@#', Fn);
  Fn.Entry := @s_rag_summary; Lib.Add('rag_summary$@#', Fn);
end;

end.

