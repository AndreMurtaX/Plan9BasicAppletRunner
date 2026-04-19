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
unit RAGEngine;

{******************************************************************************
  RAGEngine - Retrieval-Augmented Generation Engine for Plan9Basic
  Version: 1.0.0

  Provides intelligent document retrieval for the Plan9Basic Intelligence Engine.
  Indexes library documentation, language rules, code patterns, and examples,
  then retrieves the most relevant documents for a given user query.

  NO EXTERNAL DEPENDENCIES — runs entirely in Delphi with no vector databases,
  no embeddings API, and no Python. Uses multi-signal keyword scoring with
  dependency resolution and token budget management.

  ARCHITECTURE:
  =============
  Knowledge Base (disk)          RAG Engine (memory)
  ┌──────────────────┐         ┌───────────────────────────┐
  │ knowledge/       │  Load   │  FDocuments: TRAGDocList  │
  │   index.json  ────────────►│  FTagIndex: tag→[doc_ids] │
  │   libraries/     │         │  FFuncIndex: func→doc_id  │
  │   language/      │         │  FCategoryIndex           │
  │   patterns/      │         └────────────┬──────────────┘
  │   examples/      │                      │
  └──────────────────┘              Retrieve(query)
                                            │
                                   ┌────────▼─────────┐
                                   │ 1. Analyze query │
                                   │ 2. Score docs    │
                                   │ 3. Budget select │
                                   │ 4. Resolve deps  │
                                   │ 5. Load content  │
                                   └────────┬─────────┘
                                            │
                                   TArray<TRAGResult>

  DOCUMENT FORMAT:
  ================
  Knowledge documents are Markdown files with YAML-style headers:

    ---
    id: buttonlib
    title: ButtonLib - Button Controls
    category: library
    tags: button, click, gui, control, event
    functions: button#, button_text#, button_onclick#, ...
    depends: FormLib
    complexity: beginner
    platform: all
    ---
    # ButtonLib
    ...content...

  INDEX FORMAT:
  =============
  The master index (index.json) is auto-generated from document headers.
  It enables fast lookup without parsing all markdown files at startup.

  RETRIEVAL ALGORITHM:
  ====================
  Multi-signal scoring without embeddings:
    Score = (tag_matches × 3.0)
          + (title_matches × 2.5)
          + (function_matches × 5.0)
          + (category_bonus × 2.0)
          + (dependency_bonus × 1.5)
          + (example_bonus × 1.5)
          + (keyword_in_id × 3.0)

  TOKEN BUDGET:
  =============
  Retrieved documents are selected to fit within a configurable token budget
  (default 6000 tokens ≈ 25% of a 24K context). High-relevance documents
  that exceed budget are truncated to essential sections.

  USAGE:
  ======
    var RAG := TRAGEngine.Create('C:\Plan9Basic\knowledge');
    try
      RAG.LoadIndex;  // or RAG.BuildIndex to regenerate
      var Results := RAG.Retrieve('calculator with buttons', 6000);
      for var R in Results do
        WriteLn(R.Document.Title, ' (score: ', R.Score:0:2, ')');
    finally
      RAG.Free();
    end;

  Function Count: N/A (not a BASIC library — Delphi internal component)
******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.JSON,
  System.Generics.Collections, System.Generics.Defaults, System.Math,
  System.StrUtils, System.Character;

const
  // Default token budget for RAG context injection
  RAG_DEFAULT_MAX_TOKENS = 6000;

  // Approximate characters per token (conservative estimate for code/docs)
  RAG_CHARS_PER_TOKEN = 4;

  // Minimum relevance score to include a document
  RAG_MIN_RELEVANCE_SCORE = 1.0;

  // Score above which a document is considered "highly relevant"
  // and may be included even if it needs truncation
  RAG_HIGH_RELEVANCE_THRESHOLD = 8.0;

  // Maximum number of documents to return in a single retrieval
  RAG_MAX_RESULTS = 40;

  // Document categories
  RAG_CAT_LIBRARY   = 'library';
  RAG_CAT_LANGUAGE  = 'language';
  RAG_CAT_PATTERN   = 'pattern';
  RAG_CAT_EXAMPLE   = 'example';

  // Library subcategories (for tag_index grouping)
  RAG_SUBCAT_GUI_CONTROL = 'gui_control';
  RAG_SUBCAT_SHAPE       = 'shape';
  RAG_SUBCAT_EFFECT      = 'effect';
  RAG_SUBCAT_TRANSITION  = 'transition';
  RAG_SUBCAT_ANIMATION   = 'animation';
  RAG_SUBCAT_DATA        = 'data';
  RAG_SUBCAT_IO          = 'io';
  RAG_SUBCAT_NETWORK     = 'network';
  RAG_SUBCAT_SYSTEM      = 'system';

type
  // =========================================================================
  // TRAGDocument — Metadata record for a knowledge base document
  // =========================================================================
  TRAGDocument = record
    Id: String;                // Unique identifier (e.g., 'buttonlib')
    Path: String;              // Relative path from knowledge base root
    Title: String;             // Display title
    Category: String;          // 'library', 'language', 'pattern', 'example'
    Subcategory: String;       // More specific: 'gui_control', 'effect', etc.
    Tags: TArray<String>;      // Search tags
    Functions: TArray<String>; // Function names defined in this document
    Depends: TArray<String>;   // Document IDs this depends on
    Complexity: String;        // 'beginner', 'intermediate', 'advanced'
    Platform: String;          // 'all', 'desktop', 'mobile'
    SizeBytes: Integer;        // File size in bytes
    TokenEstimate: Integer;    // Estimated token count
    Summary: String;           // One-line summary for quick display

    // Content is lazy-loaded — empty until explicitly retrieved
    Content: String;
    ContentLoaded: Boolean;
  end;

  TRAGDocumentList = TArray<TRAGDocument>;

  // =========================================================================
  // TRAGResult — A scored retrieval result
  // =========================================================================
  TRAGResult = record
    Document: TRAGDocument;
    Score: Double;             // Relevance score (higher = more relevant)
    Truncated: Boolean;        // True if content was truncated to fit budget
    ContentForPrompt: String;  // Final content to inject (may be truncated)
    TokensUsed: Integer;       // Actual tokens consumed by this result
    MatchReasons: String;      // Debug: why this document was selected
  end;

  TRAGResultList = TArray<TRAGResult>;

  // =========================================================================
  // TRAGQueryAnalysis — Extracted signals from a user query
  // =========================================================================
  TRAGQueryAnalysis = record
    OriginalQuery: String;
    Keywords: TArray<String>;       // Extracted content keywords
    FunctionNames: TArray<String>;  // Detected Plan9Basic function references
    Intent: String;                 // Detected intent: 'gui', 'console', 'data', etc.
    IntentScore: Double;            // Confidence of intent detection
    IsFollowUp: Boolean;           // True if query references previous context
    LibraryHints: TArray<String>;   // Explicit library name mentions
  end;

  // =========================================================================
  // TRAGEngine — Main retrieval engine
  // =========================================================================
  TRAGEngine = class
  private
    FBasePath: String;              // Root path of knowledge base
    FIndexPath: String;             // Path to index.json
    FDocuments: TList<TRAGDocument>;
    FDocById: TDictionary<String, Integer>;          // id → index in FDocuments
    FTagIndex: TDictionary<String, TList<Integer>>;  // tag → [doc indices]
    FFuncIndex: TDictionary<String, Integer>;         // function → doc index
    FCategoryIndex: TDictionary<String, TList<Integer>>; // category → [doc indices]
    FMaxTokens: Integer;
    FIndexLoaded: Boolean;

    // Intent detection keyword sets
    FIntentKeywords: TDictionary<String, TArray<String>>;

    // Stop words to exclude from keyword extraction
    FStopWords: TDictionary<String, Boolean>;

    // Internal methods
    procedure InitializeIntentKeywords();
    procedure InitializeStopWords();
    procedure ClearIndex();
    procedure AddDocumentToIndices(DocIndex: Integer);

    // Query analysis
    function AnalyzeQuery(const Query: String): TRAGQueryAnalysis;
    function ExtractKeywords(const Query: String): TArray<String>;
    function DetectFunctionNames(const Query: String): TArray<String>;
    function DetectIntent(const Keywords: TArray<String>): String;
    function DetectLibraryHints(const Query: String): TArray<String>;

    // Scoring
    function ScoreDocument(DocIndex: Integer; const Analysis: TRAGQueryAnalysis; const AlreadySelected: TList<Integer>): Double;
    function BuildMatchReasons(DocIndex: Integer; const Analysis: TRAGQueryAnalysis): String;

    // Content loading and truncation
    function LoadDocumentContent(var Doc: TRAGDocument): String;
    function TruncateContent(const Content: String; MaxTokens: Integer): String;
    function ExtractEssentialSections(const Content: String; MaxTokens: Integer): String;
    function EstimateTokens(const Text: String): Integer;

    // Dependency resolution
    procedure ResolveDependencies(Selected: TList<Integer>);

    // Index I/O
    function ParseDocumentHeader(const FilePath: String): TRAGDocument;
    function DocumentToJSON(const Doc: TRAGDocument): TJSONObject;
    function JSONToDocument(const Obj: TJSONObject): TRAGDocument;

    // Helpers
    function NormalizeTag(const Tag: String): String;
    function ArrayContains(const Arr: TArray<String>; const Value: String): Boolean;
    function SplitCSV(const S: String): TArray<String>;
  public
    constructor Create(const BasePath: String);
    destructor Destroy(); override;

    // === Index Management ===

    /// <summary>Load the master index from index.json</summary>
    procedure LoadIndex();

    /// <summary>Build/rebuild index by scanning all knowledge base files</summary>
    procedure BuildIndex();

    /// <summary>Save the current in-memory index to index.json</summary>
    procedure SaveIndex();

    // === Core Retrieval ===

    /// <summary>Retrieve relevant documents for a natural language query</summary>
    /// <param name="Query">User's natural language request</param>
    /// <param name="MaxTokens">Maximum token budget (0 = use default)</param>
    /// <returns>Scored, ranked array of results with content ready for prompt injection</returns>
    function Retrieve(const Query: String; MaxTokens: Integer = 0): TRAGResultList;

    /// <summary>Retrieve documents matching specific function names</summary>
    function RetrieveByFunctions(const Functions: TArray<String>): TRAGResultList;

    /// <summary>Retrieve documents matching specific tags</summary>
    function RetrieveByTags(const Tags: TArray<String>): TRAGResultList;

    /// <summary>Get a single document by ID with full content</summary>
    function GetDocument(const Id: String): TRAGDocument;

    // === Query Analysis (exposed for testing/debugging) ===

    /// <summary>Analyze a query without performing retrieval</summary>
    function Analyze(const Query: String): TRAGQueryAnalysis;

    // === Information ===

    /// <summary>Total number of indexed documents</summary>
    function DocumentCount(): Integer;

    /// <summary>Total number of indexed functions</summary>
    function FunctionCount(): Integer;

    /// <summary>List all document IDs</summary>
    function ListDocumentIds(): TArray<String>;

    /// <summary>List all indexed tags</summary>
    function ListTags(): TArray<String>;

    /// <summary>List all categories with document counts</summary>
    function ListCategories(): TArray<String>;

    /// <summary>Get a formatted summary of the index for diagnostics</summary>
    function GetIndexSummary(): String;

    // === Properties ===
    property BasePath: String read FBasePath;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property IndexLoaded: Boolean read FIndexLoaded;
  end;

implementation

{ ============================================================================
  CONSTRUCTOR / DESTRUCTOR
  ============================================================================ }

constructor TRAGEngine.Create(const BasePath: String);
begin
  inherited Create();
  FBasePath := IncludeTrailingPathDelimiter(BasePath);
  FIndexPath := FBasePath + 'index.json';
  FMaxTokens := RAG_DEFAULT_MAX_TOKENS;
  FIndexLoaded := False;

  FDocuments := TList<TRAGDocument>.Create();
  FDocById := TDictionary<String, Integer>.Create();
  FTagIndex := TDictionary<String, TList<Integer>>.Create();
  FFuncIndex := TDictionary<String, Integer>.Create();
  FCategoryIndex := TDictionary<String, TList<Integer>>.Create();

  FIntentKeywords := TDictionary<String, TArray<String>>.Create();
  FStopWords := TDictionary<String, Boolean>.Create();

  InitializeIntentKeywords;
  InitializeStopWords;
end;

destructor TRAGEngine.Destroy();
begin
  ClearIndex;
  FDocuments.Free();
  FDocById.Free();

  // Free TList instances inside FTagIndex
  for var Pair in FTagIndex do
    Pair.Value.Free();
  FTagIndex.Free();

  FFuncIndex.Free();

  // Free TList instances inside FCategoryIndex
  for var Pair in FCategoryIndex do
    Pair.Value.Free();
  FCategoryIndex.Free();

  FIntentKeywords.Free();
  FStopWords.Free();
  inherited;
end;

{ ============================================================================
  INITIALIZATION
  ============================================================================ }

procedure TRAGEngine.InitializeIntentKeywords();
begin
  FIntentKeywords.Add('gui', TArray<String>.Create(
    'form', 'window', 'button', 'gui', 'app', 'applet', 'interface', 'screen',
    'dialog', 'visual', 'click', 'menu', 'toolbar', 'panel', 'label', 'edit',
    'checkbox', 'combobox', 'listbox', 'image', 'widget', 'layout', 'control',
    'textbox', 'input', 'display', 'radio', 'switch', 'slider', 'trackbar',
    'progress', 'grid', 'table', 'memo', 'speedbutton', 'tab')
  );

  FIntentKeywords.Add('console', TArray<String>.Create(
    'console', 'text', 'print', 'println', 'input', 'command', 'cli',
    'terminal', 'output', 'prompt', 'stdin', 'stdout', 'hello')
  );

  FIntentKeywords.Add('data', TArray<String>.Create(
    'file', 'json', 'csv', 'xml', 'read', 'write', 'parse', 'data', 'load',
    'save', 'import', 'export', 'config', 'ini', 'array', 'dictionary',
    'list', 'sort', 'filter', 'record', 'struct')
  );

  FIntentKeywords.Add('network', TArray<String>.Create(
    'http', 'api', 'request', 'web', 'fetch', 'download', 'url', 'post',
    'get', 'rest', 'endpoint', 'server', 'client', 'upload', 'socket',
    'response', 'header')
  );

  FIntentKeywords.Add('database', TArray<String>.Create(
    'database', 'sqlite', 'query', 'table', 'sql', 'crud', 'record',
    'field', 'select', 'insert', 'update', 'delete', 'schema', 'row',
    'column', 'index')
  );

  FIntentKeywords.Add('animation', TArray<String>.Create(
    'animate', 'move', 'fade', 'rotate', 'transition', 'effect', 'tween',
    'interpolate', 'keyframe', 'timeline', 'color', 'glow', 'blur',
    'ripple', 'swirl')
  );

  FIntentKeywords.Add('game', TArray<String>.Create(
    'game', 'score', 'player', 'collision', 'sprite', 'level', 'enemy',
    'health', 'lives', 'random', 'physics', 'bounce')
  );

  FIntentKeywords.Add('system', TArray<String>.Create(
    'os', 'platform', 'environment', 'system', 'process', 'execute', 'shell',
    'directory', 'path', 'date', 'time', 'clipboard', 'regex', 'timer',
    'base64', 'gzip', 'zip')
  );

  FIntentKeywords.Add('shape', TArray<String>.Create(
    'draw', 'shape', 'circle', 'rectangle', 'ellipse', 'line', 'arc',
    'pie', 'path', 'polygon', 'round', 'canvas', 'paint', 'graphic')
  );
end;

procedure TRAGEngine.InitializeStopWords();
const
  STOP_WORDS: array[0..59] of String = (
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'shall', 'can', 'need', 'dare', 'ought',
    'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he', 'she', 'it',
    'they', 'them', 'that', 'this', 'these', 'those', 'what', 'which',
    'who', 'whom', 'where', 'when', 'why', 'how', 'of', 'in', 'to',
    'for', 'with', 'on', 'at', 'from', 'by'
  );
begin
  for var W in STOP_WORDS do
    FStopWords.AddOrSetValue(W, True);
end;

procedure TRAGEngine.ClearIndex();
begin
  FDocuments.Clear();
  FDocById.Clear();

  for var Pair in FTagIndex do
    Pair.Value.Free();
  FTagIndex.Clear();

  FFuncIndex.Clear();

  for var Pair in FCategoryIndex do
    Pair.Value.Free();
  FCategoryIndex.Clear();

  FIndexLoaded := False;
end;

procedure TRAGEngine.AddDocumentToIndices(DocIndex: Integer);
var
  Doc: TRAGDocument;
  NormTag: String;
  TagList: TList<Integer>;
  CatList: TList<Integer>;
begin
  Doc := FDocuments[DocIndex];

  // ID index
  FDocById.AddOrSetValue(LowerCase(Doc.Id), DocIndex);

  // Tag index
  for var Tag in Doc.Tags do
  begin
    NormTag := NormalizeTag(Tag);
    if NormTag = '' then Continue;

    if not FTagIndex.TryGetValue(NormTag, TagList) then
    begin
      TagList := TList<Integer>.Create();
      FTagIndex.Add(NormTag, TagList);
    end;
    if not TagList.Contains(DocIndex) then
      TagList.Add(DocIndex);
  end;

  // Function index
  for var Func in Doc.Functions do
  begin
    if Func <> '' then
      FFuncIndex.AddOrSetValue(LowerCase(Func), DocIndex);
  end;

  // Category index
  if Doc.Category <> '' then
  begin
    if not FCategoryIndex.TryGetValue(LowerCase(Doc.Category), CatList) then
    begin
      CatList := TList<Integer>.Create();
      FCategoryIndex.Add(LowerCase(Doc.Category), CatList);
    end;
    if not CatList.Contains(DocIndex) then
      CatList.Add(DocIndex);
  end;
end;

{ ============================================================================
  INDEX MANAGEMENT
  ============================================================================ }

procedure TRAGEngine.LoadIndex();
var
  JsonStr: String;
  JsonRoot, DocObj: TJSONObject;
  DocsArray: TJSONArray;
  Doc: TRAGDocument;
  Idx: Integer;
begin
  ClearIndex;

  if not TFile.Exists(FIndexPath) then
  begin
    // No index file — build from scratch
    BuildIndex();
    Exit();
  end;

  JsonStr := TFile.ReadAllText(FIndexPath, TEncoding.UTF8);
  JsonRoot := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  if JsonRoot = nil then
    raise Exception.Create('RAGEngine: Invalid index.json format');

  try
    DocsArray := JsonRoot.GetValue<TJSONArray>('documents');
    if DocsArray = nil then
      raise Exception.Create('RAGEngine: Missing "documents" array in index.json');

    for var I := 0 to DocsArray.Count - 1 do
    begin
      DocObj := DocsArray.Items[I] as TJSONObject;
      Doc := JSONToDocument(DocObj);
      Idx := FDocuments.Add(Doc);
      AddDocumentToIndices(Idx);
    end;

    FIndexLoaded := True;
  finally
    JsonRoot.Free();
  end;
end;

//procedure TRAGEngine.BuildIndex();
//var
//  SearchPath, RelPath: String;
//  Files: TArray<String>;
//  Doc: TRAGDocument;
//  Idx: Integer;
//  Subdirs: array[0..3] of String;
//begin
//  ClearIndex;
//
//  Subdirs[0] := 'libraries';
//  Subdirs[1] := 'language';
//  Subdirs[2] := 'patterns';
//  Subdirs[3] := 'examples';
//
//  for var Subdir in Subdirs do
//  begin
//    SearchPath := FBasePath + Subdir;
//    if not TDirectory.Exists(SearchPath) then
//      Continue;
//
//    // Scan for .md files
//    Files := TDirectory.GetFiles(SearchPath, '*.md',
//      TSearchOption.soAllDirectories);
//
//    for var FilePath in Files do
//    begin
//      try
//        Doc := ParseDocumentHeader(FilePath);
//        if Doc.Id = '' then Continue; // Skip files without valid headers
//
//        // Set relative path
//        RelPath := FilePath;
//        if RelPath.StartsWith(FBasePath) then
//          RelPath := RelPath.Substring(Length(FBasePath));
//        Doc.Path := RelPath;
//
//        // Estimate tokens from file size
//        Doc.SizeBytes := Integer(TFile.GetSize(FilePath));
//        if Doc.TokenEstimate = 0 then
//          Doc.TokenEstimate := Doc.SizeBytes div RAG_CHARS_PER_TOKEN;
//
//        Idx := FDocuments.Add(Doc);
//        AddDocumentToIndices(Idx);
//      except
//        on E: Exception do
//        begin
//          // Log but continue — don't let one bad file break the whole index
//          {$IFDEF DEBUG}
//          WriteLn('RAGEngine: Error indexing ', FilePath, ': ', E.Message);
//          {$ENDIF}
//        end;
//      end;
//    end;
//
//    // Also scan for .bas example files
//    if Subdir = 'examples' then
//    begin
//      Files := TDirectory.GetFiles(SearchPath, '*.bas',
//        TSearchOption.soAllDirectories);
//      for var FilePath in Files do
//      begin
//        try
//          Doc := Default(TRAGDocument);
//          Doc.Id := LowerCase(ChangeFileExt(ExtractFileName(FilePath), ''));
//          Doc.Title := Doc.Id + ' (example)';
//          Doc.Category := RAG_CAT_EXAMPLE;
//          Doc.Complexity := 'beginner';
//          Doc.Platform := 'all';
//
//          RelPath := FilePath;
//          if RelPath.StartsWith(FBasePath) then
//            RelPath := RelPath.Substring(Length(FBasePath));
//          Doc.Path := RelPath;
//
//          Doc.SizeBytes := Integer(TFile.GetSize(FilePath));
//          Doc.TokenEstimate := Doc.SizeBytes div RAG_CHARS_PER_TOKEN;
//
//          // Extract tags from filename
//          Doc.Tags := TArray<String>.Create(Doc.Id, 'example', 'sample');
//
//          Idx := FDocuments.Add(Doc);
//          AddDocumentToIndices(Idx);
//        except
//          // Skip bad files
//        end;
//      end;
//    end;
//  end;
//
//  FIndexLoaded := True;
//
//  // Auto-save the generated index
//  SaveIndex;
//end;
procedure TRAGEngine.BuildIndex();
var
  SearchPath, RelPath: String;
  Files: TArray<String>;
  Doc: TRAGDocument;
  Idx: Integer;
  Subdirs: array[0..3] of String;
begin
  ClearIndex();

  // *** FIX: First scan root-level .md files in knowledge/ ***
  if TDirectory.Exists(FBasePath) then
  begin
    // GetFiles with soTopDirectoryOnly — only root level, not recursive
    Files := TDirectory.GetFiles(FBasePath, '*.md', TSearchOption.soTopDirectoryOnly);

    for var FilePath in Files do
    begin
      try
        Doc := ParseDocumentHeader(FilePath);
        if Doc.Id = '' then Continue;

        RelPath := FilePath;
        if RelPath.StartsWith(FBasePath) then
          RelPath := RelPath.Substring(Length(FBasePath));
        Doc.Path := RelPath;

        Doc.SizeBytes := Integer(TFile.GetSize(FilePath));
        if Doc.TokenEstimate = 0 then
          Doc.TokenEstimate := Doc.SizeBytes div RAG_CHARS_PER_TOKEN;

        Idx := FDocuments.Add(Doc);
        AddDocumentToIndices(Idx);
      except
        on E: Exception do
        begin
          {$IFDEF DEBUG}
          WriteLn('RAGEngine: Error indexing ', FilePath, ': ', E.Message);
          {$ENDIF}
        end;
      end;
    end;
  end;

  // Now scan subdirectories (existing logic, unchanged)
  Subdirs[0] := 'libraries';
  Subdirs[1] := 'language';
  Subdirs[2] := 'patterns';
  Subdirs[3] := 'examples';

  for var Subdir in Subdirs do
  begin
    SearchPath := FBasePath + Subdir;
    if not TDirectory.Exists(SearchPath) then
      Continue;

    // Scan for .md files
    Files := TDirectory.GetFiles(SearchPath, '*.md',
      TSearchOption.soAllDirectories);

    for var FilePath in Files do
    begin
      try
        Doc := ParseDocumentHeader(FilePath);
        if Doc.Id = '' then Continue; // Skip files without valid headers

        // Set relative path
        RelPath := FilePath;
        if RelPath.StartsWith(FBasePath) then
          RelPath := RelPath.Substring(Length(FBasePath));
        Doc.Path := RelPath;

        // Estimate tokens from file size
        Doc.SizeBytes := Integer(TFile.GetSize(FilePath));
        if Doc.TokenEstimate = 0 then
          Doc.TokenEstimate := Doc.SizeBytes div RAG_CHARS_PER_TOKEN;

        Idx := FDocuments.Add(Doc);
        AddDocumentToIndices(Idx);
      except
        on E: Exception do
        begin
          // Log but continue — don't let one bad file break the whole index
          {$IFDEF DEBUG}
          WriteLn('RAGEngine: Error indexing ', FilePath, ': ', E.Message);
          {$ENDIF}
        end;
      end;
    end;

    // Also scan for .bas example files
    if Subdir = 'examples' then
    begin
      Files := TDirectory.GetFiles(SearchPath, '*.bas',
        TSearchOption.soAllDirectories);
      for var FilePath in Files do
      begin
        try
          Doc := Default(TRAGDocument);
          Doc.Id := LowerCase(ChangeFileExt(ExtractFileName(FilePath), ''));
          Doc.Title := Doc.Id + ' (example)';
          Doc.Category := RAG_CAT_EXAMPLE;
          Doc.Complexity := 'beginner';
          Doc.Platform := 'all';

          RelPath := FilePath;
          if RelPath.StartsWith(FBasePath) then
            RelPath := RelPath.Substring(Length(FBasePath));
          Doc.Path := RelPath;

          Doc.SizeBytes := Integer(TFile.GetSize(FilePath));
          Doc.TokenEstimate := Doc.SizeBytes div RAG_CHARS_PER_TOKEN;

          // Extract tags from filename
          Doc.Tags := TArray<String>.Create(Doc.Id, 'example', 'sample');

          Idx := FDocuments.Add(Doc);
          AddDocumentToIndices(Idx);
        except
          // Skip bad files
        end;
      end;
    end;
  end;

  FIndexLoaded := True;

  // Auto-save the generated index
  SaveIndex;
end;

procedure TRAGEngine.SaveIndex();
var
  JsonRoot: TJSONObject;
  DocsArray: TJSONArray;
begin
  JsonRoot := TJSONObject.Create();
  try
    JsonRoot.AddPair('version', TJSONNumber.Create(1));
    JsonRoot.AddPair('generated', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
    JsonRoot.AddPair('document_count', TJSONNumber.Create(FDocuments.Count));
    JsonRoot.AddPair('function_count', TJSONNumber.Create(FFuncIndex.Count));
    JsonRoot.AddPair('tag_count', TJSONNumber.Create(FTagIndex.Count));

    DocsArray := TJSONArray.Create();
    for var I := 0 to FDocuments.Count - 1 do
      DocsArray.AddElement(DocumentToJSON(FDocuments[I]));
    JsonRoot.AddPair('documents', DocsArray);

    // Ensure directory exists
    try
      TDirectory.CreateDirectory(ExtractFilePath(FIndexPath));
    except
      // On mobile the path may not be writable; continue without saving.
      // The index is still valid in memory for the current session.
      Exit();
    end;

    try
      TFile.WriteAllText(FIndexPath, JsonRoot.Format(2), TEncoding.UTF8);
    except
      // Write failure (e.g. read-only path on mobile) — index remains
      // in memory and will work for this session. Non-fatal.
      {$IFDEF DEBUG}
      // WriteLn('RAGEngine.SaveIndex: failed to write ' + FIndexPath);
      {$ENDIF}
    end;
  finally
    JsonRoot.Free();
  end;
end;

{ ============================================================================
  QUERY ANALYSIS
  ============================================================================ }

function TRAGEngine.AnalyzeQuery(const Query: String): TRAGQueryAnalysis;
begin
  Result := Default(TRAGQueryAnalysis);
  Result.OriginalQuery := Query;
  Result.Keywords := ExtractKeywords(Query);
  Result.FunctionNames := DetectFunctionNames(Query);
  Result.Intent := DetectIntent(Result.Keywords);
  Result.LibraryHints := DetectLibraryHints(Query);
  Result.IsFollowUp := (Pos('also', LowerCase(Query)) > 0) or
                        (Pos('change', LowerCase(Query)) > 0) or
                        (Pos('modify', LowerCase(Query)) > 0) or
                        (Pos('add to', LowerCase(Query)) > 0) or
                        (Pos('update', LowerCase(Query)) > 0);
end;

function TRAGEngine.Analyze(const Query: String): TRAGQueryAnalysis;
begin
  Result := AnalyzeQuery(Query);
end;

function TRAGEngine.ExtractKeywords(const Query: String): TArray<String>;
var
  Words: TArray<String>;
  Cleaned: String;
  Results: TList<String>;
  LW: String;
begin
  // Normalize: lowercase, replace punctuation with spaces
  Cleaned := LowerCase(Query);
  for var I := 1 to Length(Cleaned) do
    if not (Cleaned[I].IsLetterOrDigit or (Cleaned[I] = '_') or
            (Cleaned[I] = '#') or (Cleaned[I] = '$') or (Cleaned[I] = ' ')) then
      Cleaned[I] := ' ';

  Words := Cleaned.Split([' '], TStringSplitOptions.ExcludeEmpty);
  Results := TList<String>.Create();
  try
    for var W in Words do
    begin
      LW := Trim(W);
      if LW = '' then Continue;
      if LW.Length < 2 then Continue;

      // Skip stop words (but keep Plan9Basic-relevant short words)
      if FStopWords.ContainsKey(LW) then Continue;

      // Skip common filler verbs
      if (LW = 'create') or (LW = 'make') or (LW = 'build') or
         (LW = 'want') or (LW = 'need') or (LW = 'please') or
         (LW = 'help') or (LW = 'show') or (LW = 'using') or
         (LW = 'like') or (LW = 'just') or (LW = 'some') then Continue;

      if not Results.Contains(LW) then
        Results.Add(LW);
    end;

    Result := Results.ToArray;
  finally
    Results.Free();
  end;
end;

function TRAGEngine.DetectFunctionNames(const Query: String): TArray<String>;
var
  Words: TArray<String>;
  Results: TList<String>;
  LW: String;
begin
  // Look for words ending in # or $ or matching known function patterns
  Words := LowerCase(Query).Split([' ', ',', ';', '(', ')'],
    TStringSplitOptions.ExcludeEmpty);

  Results := TList<String>.Create();
  try
    for var W in Words do
    begin
      LW := Trim(W);
      if LW = '' then Continue;

      // Direct function name references (with # or $ suffix)
      if LW.EndsWith('#') or LW.EndsWith('$') then
      begin
        if not Results.Contains(LW) then
          Results.Add(LW);
        Continue;
      end;

      // Check against known function index
      if FFuncIndex.ContainsKey(LW) then
      begin
        if not Results.Contains(LW) then
          Results.Add(LW);
        Continue;
      end;

      // Check with common suffixes
      if FFuncIndex.ContainsKey(LW + '#') then
      begin
        if not Results.Contains(LW + '#') then
          Results.Add(LW + '#');
      end;

      if FFuncIndex.ContainsKey(LW + '$') then
      begin
        if not Results.Contains(LW + '$') then
          Results.Add(LW + '$');
      end;
    end;

    Result := Results.ToArray;
  finally
    Results.Free();
  end;
end;

function TRAGEngine.DetectIntent(const Keywords: TArray<String>): String;
var
  Scores: TDictionary<String, Double>;
  BestIntent: String;
  BestScore, Score: Double;
  IntentWords: TArray<String>;
begin
  Result := '';
  Scores := TDictionary<String, Double>.Create();
  try
    // Score each intent category
    for var Pair in FIntentKeywords do
    begin
      Score := 0;
      IntentWords := Pair.Value;
      for var KW in Keywords do
      begin
        for var IW in IntentWords do
        begin
          if KW = IW then
            Score := Score + 1.0
          else if KW.Contains(IW) or IW.Contains(KW) then
            Score := Score + 0.5;
        end;
      end;
      Scores.AddOrSetValue(Pair.Key, Score);
    end;

    // Find highest scoring intent
    BestScore := 0;
    BestIntent := 'console'; // Default fallback
    for var Pair in Scores do
    begin
      if Pair.Value > BestScore then
      begin
        BestScore := Pair.Value;
        BestIntent := Pair.Key;
      end;
    end;

    // Only return intent if we have reasonable confidence
    if BestScore >= 1.0 then
      Result := BestIntent
    else
      Result := ''; // No clear intent detected
  finally
    Scores.Free();
  end;
end;

function TRAGEngine.DetectLibraryHints(const Query: String): TArray<String>;
var
  LQ: String;
  Results: TList<String>;
begin
  LQ := LowerCase(Query);
  Results := TList<String>.Create();
  try
    // Check for explicit library name mentions
    for var I := 0 to FDocuments.Count - 1 do
    begin
      if FDocuments[I].Category <> RAG_CAT_LIBRARY then Continue;

      // Check if the library ID appears in the query (e.g., "formlib", "buttonlib")
      if Pos(LowerCase(FDocuments[I].Id), LQ) > 0 then
      begin
        if not Results.Contains(FDocuments[I].Id) then
          Results.Add(FDocuments[I].Id);
      end;
    end;

    Result := Results.ToArray;
  finally
    Results.Free();
  end;
end;

{ ============================================================================
  CORE RETRIEVAL
  ============================================================================ }

function TRAGEngine.Retrieve(const Query: String;
  MaxTokens: Integer): TRAGResultList;
var
  Analysis: TRAGQueryAnalysis;
  Scores: TList<TPair<Integer, Double>>;
  Selected: TList<Integer>;
  Results: TList<TRAGResult>;
  Budget, TokensUsed: Integer;
  R: TRAGResult;
  Doc: TRAGDocument;
  Content: String;
  DocTokens: Integer;
begin
  if not FIndexLoaded then
    raise Exception.Create('RAGEngine: Index not loaded. Call LoadIndex first.');

  if MaxTokens <= 0 then
    MaxTokens := FMaxTokens;
  Budget := MaxTokens;

  Analysis := AnalyzeQuery(Query);

  // Phase 1: Score all documents
  Scores := TList<TPair<Integer, Double>>.Create();
  try
    for var I := 0 to FDocuments.Count - 1 do
    begin
      var Score := ScoreDocument(I, Analysis, nil);
      if Score >= RAG_MIN_RELEVANCE_SCORE then
        Scores.Add(TPair<Integer, Double>.Create(I, Score));
    end;

    // Sort by score descending
    Scores.Sort(TComparer<TPair<Integer, Double>>.Construct(
      function(const A, B: TPair<Integer, Double>): Integer
      begin
        if A.Value > B.Value then Result := -1
        else if A.Value < B.Value then Result := 1
        else Result := 0;
      end
    ));

    // Phase 2: Select within token budget
    Selected := TList<Integer>.Create();
    Results := TList<TRAGResult>.Create();
    try
      TokensUsed := 0;

      for var Pair in Scores do
      begin
        if Selected.Count >= RAG_MAX_RESULTS then Break;

        Doc := FDocuments[Pair.Key];
        DocTokens := Doc.TokenEstimate;

        if TokensUsed + DocTokens <= Budget then
        begin
          // Fits within budget — include fully
          Selected.Add(Pair.Key);
          TokensUsed := TokensUsed + DocTokens;
        end
        else if (Pair.Value >= RAG_HIGH_RELEVANCE_THRESHOLD) and
                (TokensUsed < Budget) then
        begin
          // Highly relevant but too big — include truncated
          Selected.Add(Pair.Key);
          DocTokens := Budget - TokensUsed;
          TokensUsed := Budget; // Use remaining budget
        end;
        // Otherwise skip — doesn't fit
      end;

      // Phase 3: Dependency resolution
      ResolveDependencies(Selected);

      // Phase 4: Build results with loaded content
      for var DocIdx in Selected do
      begin
        Doc := FDocuments[DocIdx];
        R := Default(TRAGResult);
        R.Document := Doc;

        // Calculate score (may be a dependency with score 0 — that's OK)
        R.Score := 0;
        for var Pair in Scores do
        begin
          if Pair.Key = DocIdx then
          begin
            R.Score := Pair.Value;
            Break;
          end;
        end;

        // Load content
        Content := LoadDocumentContent(Doc);
        DocTokens := EstimateTokens(Content);

        // Check if truncation is needed
        var RemainingBudget := Budget;
        for var Existing in Results do
          RemainingBudget := RemainingBudget - Existing.TokensUsed;

        if DocTokens > RemainingBudget then
        begin
          Content := ExtractEssentialSections(Content, RemainingBudget);
          DocTokens := EstimateTokens(Content);
          R.Truncated := True;
        end
        else
          R.Truncated := False;

        R.ContentForPrompt := Content;
        R.TokensUsed := DocTokens;
        R.MatchReasons := BuildMatchReasons(DocIdx, Analysis);

        // Update document in main list with loaded content
        Doc.Content := Content;
        Doc.ContentLoaded := True;
        FDocuments[DocIdx] := Doc;

        Results.Add(R);
      end;

      // Sort results: highest score first, but language rules always at top
      Results.Sort(TComparer<TRAGResult>.Construct(
        function(const A, B: TRAGResult): Integer
        begin
          // Language docs always come first
          if (A.Document.Category = RAG_CAT_LANGUAGE) and
             (B.Document.Category <> RAG_CAT_LANGUAGE) then
            Result := -1
          else if (A.Document.Category <> RAG_CAT_LANGUAGE) and
                  (B.Document.Category = RAG_CAT_LANGUAGE) then
            Result := 1
          else
          begin
            // Then by score
            if A.Score > B.Score then Result := -1
            else if A.Score < B.Score then Result := 1
            else Result := 0;
          end;
        end
      ));

      Result := Results.ToArray;
    finally
      Results.Free();
      Selected.Free();
    end;
  finally
    Scores.Free();
  end;
end;

function TRAGEngine.RetrieveByFunctions(
  const Functions: TArray<String>): TRAGResultList;
var
  DocIndices: TList<Integer>;
  Idx: Integer;
  ResultList: TList<TRAGResult>;
  R: TRAGResult;
  Doc: TRAGDocument;
begin
  DocIndices := TList<Integer>.Create();
  ResultList := TList<TRAGResult>.Create();
  try
    // Find documents containing each function
    for var Func in Functions do
    begin
      if FFuncIndex.TryGetValue(LowerCase(Func), Idx) then
      begin
        if not DocIndices.Contains(Idx) then
          DocIndices.Add(Idx);
      end;
    end;

    // Resolve dependencies
    ResolveDependencies(DocIndices);

    // Build results
    for var DocIdx in DocIndices do
    begin
      Doc := FDocuments[DocIdx];
      R := Default(TRAGResult);
      R.Document := Doc;
      R.Score := 5.0; // Fixed score for explicit function lookup
      R.ContentForPrompt := LoadDocumentContent(Doc);
      R.TokensUsed := EstimateTokens(R.ContentForPrompt);
      R.Truncated := False;
      R.MatchReasons := 'Function lookup';
      ResultList.Add(R);
    end;

    Result := ResultList.ToArray;
  finally
    ResultList.Free();
    DocIndices.Free();
  end;
end;

function TRAGEngine.RetrieveByTags(
  const Tags: TArray<String>): TRAGResultList;
var
  DocIndices: TList<Integer>;
  TagList: TList<Integer>;
  ResultList: TList<TRAGResult>;
  R: TRAGResult;
  Doc: TRAGDocument;
begin
  DocIndices := TList<Integer>.Create();
  ResultList := TList<TRAGResult>.Create();
  try
    for var Tag in Tags do
    begin
      if FTagIndex.TryGetValue(NormalizeTag(Tag), TagList) then
      begin
        for var Idx in TagList do
        begin
          if not DocIndices.Contains(Idx) then
            DocIndices.Add(Idx);
        end;
      end;
    end;

    for var DocIdx in DocIndices do
    begin
      Doc := FDocuments[DocIdx];
      R := Default(TRAGResult);
      R.Document := Doc;
      R.Score := 3.0;
      R.ContentForPrompt := LoadDocumentContent(Doc);
      R.TokensUsed := EstimateTokens(R.ContentForPrompt);
      R.MatchReasons := 'Tag lookup';
      ResultList.Add(R);
    end;

    Result := ResultList.ToArray;
  finally
    ResultList.Free();
    DocIndices.Free();
  end;
end;

function TRAGEngine.GetDocument(const Id: String): TRAGDocument;
var
  Idx: Integer;
  Doc: TRAGDocument;
begin
  if FDocById.TryGetValue(LowerCase(Id), Idx) then
  begin
    Doc := FDocuments[Idx];
    if not Doc.ContentLoaded then
    begin
      Doc.Content := LoadDocumentContent(Doc);
      Doc.ContentLoaded := True;
      FDocuments[Idx] := Doc;
    end;
    Result := Doc;
  end
  else
    raise Exception.CreateFmt('RAGEngine: Document not found: %s', [Id]);
end;

{ ============================================================================
  SCORING
  ============================================================================ }

function TRAGEngine.ScoreDocument(DocIndex: Integer; const Analysis: TRAGQueryAnalysis; const AlreadySelected: TList<Integer>): Double;
var
  Doc: TRAGDocument;
  Score: Double;
  TagHits, TitleHits, FuncHits, IdHits: Integer;
  NormTag, LowId, LowTitle: String;
  TagList: TList<Integer>;
begin
  Doc := FDocuments[DocIndex];
  Score := 0;
  LowId := LowerCase(Doc.Id);
  LowTitle := LowerCase(Doc.Title);

  // --- Signal 1: Tag matches (weight 3.0) ---
  TagHits := 0;
  for var KW in Analysis.Keywords do
  begin
    for var Tag in Doc.Tags do
    begin
      NormTag := NormalizeTag(Tag);
      if KW = NormTag then
        Inc(TagHits)
      else if (KW.Length >= 3) and (NormTag.Contains(KW) or KW.Contains(NormTag)) then
        TagHits := TagHits + 1; // Partial match counts as half? No, keep 1 for simplicity
    end;
  end;
  Score := Score + (TagHits * 3.0);

  // --- Signal 2: Title keyword matches (weight 2.5) ---
  TitleHits := 0;
  for var KW in Analysis.Keywords do
  begin
    if LowTitle.Contains(KW) then
      Inc(TitleHits);
  end;
  Score := Score + (TitleHits * 2.5);

  // --- Signal 3: Function name matches (weight 5.0 — highest priority) ---
  FuncHits := 0;
  for var FN in Analysis.FunctionNames do
  begin
    for var DocFunc in Doc.Functions do
    begin
      if LowerCase(FN) = LowerCase(DocFunc) then
        Inc(FuncHits)
      else if LowerCase(DocFunc).StartsWith(LowerCase(FN.Replace('#', '').Replace('$', ''))) then
        Inc(FuncHits); // Partial: user typed "button_text" and doc has "button_text#"
    end;
  end;
  Score := Score + (FuncHits * 5.0);

  // --- Signal 4: Direct ID match in keywords (weight 3.0) ---
  IdHits := 0;
  for var KW in Analysis.Keywords do
  begin
    if LowId = KW then
      IdHits := IdHits + 2  // Exact match
    else if LowId.Contains(KW) and (KW.Length >= 3) then
      Inc(IdHits);  // Partial match
  end;
  Score := Score + (IdHits * 3.0);

  // --- Signal 5: Explicit library hint (weight 10.0 — user named the lib) ---
  for var Hint in Analysis.LibraryHints do
  begin
    if LowerCase(Hint) = LowId then
    begin
      Score := Score + 10.0;
      Break;
    end;
  end;

  // --- Signal 6: Category matches detected intent (weight 2.0) ---
  if Analysis.Intent <> '' then
  begin
    // Map intents to subcategories
    // --- Signal 8: Constructor cheat sheet bonus for GUI intent ---
    if (Analysis.Intent = 'gui') and (LowId = 'constructors') then
      Score := Score + 8.0 // Ensure it's always included for GUI applets
    else if ((Analysis.Intent = 'gui') and ((Doc.Subcategory = RAG_SUBCAT_GUI_CONTROL) or (Doc.Subcategory = RAG_SUBCAT_SHAPE))) then
      Score := Score + 2.0
    else if ((Analysis.Intent = 'shape') and (Doc.Subcategory = RAG_SUBCAT_SHAPE)) then
      Score := Score + 2.0
    else if ((Analysis.Intent = 'animation') and (Doc.Subcategory = RAG_SUBCAT_ANIMATION)) then
      Score := Score + 2.0
    else if ((Analysis.Intent = 'data') and ((Doc.Subcategory = RAG_SUBCAT_DATA) or (Doc.Subcategory = RAG_SUBCAT_IO))) then
      Score := Score + 2.0
    else if ((Analysis.Intent = 'network') and (Doc.Subcategory = RAG_SUBCAT_NETWORK)) then
      Score := Score + 2.0
    else if ((Analysis.Intent = 'system') and (Doc.Subcategory = RAG_SUBCAT_SYSTEM)) then
      Score := Score + 2.0;

    // Bonus for example documents matching the intent
    if Doc.Category = RAG_CAT_EXAMPLE then
    begin
      // Check if example tags match intent keywords
      var IntentWords: TArray<String>;
      if FIntentKeywords.TryGetValue(Analysis.Intent, IntentWords) then
      begin
        for var Tag in Doc.Tags do
        begin
          for var IW in IntentWords do
          begin
            if NormalizeTag(Tag) = IW then
            begin
              Score := Score + 1.5;
              Break;
            end;
          end;
        end;
      end;
    end;
  end;

  // --- Signal 7: Dependency pull-up bonus ---
  // If already-selected docs depend on this one, boost it
  if AlreadySelected <> nil then
  begin
    for var SelIdx in AlreadySelected do
    begin
      for var Dep in FDocuments[SelIdx].Depends do
      begin
        if LowerCase(Dep) = LowId then
        begin
          Score := Score + 1.5;
          Break;
        end;
      end;
    end;
  end;

  // --- Signal 8: Language rules always get a base boost ---
  if Doc.Category = RAG_CAT_LANGUAGE then
  begin
    // Language rules are almost always useful — small baseline boost
    Score := Score + 0.5;

    // Specific language docs get extra boost if keywords match
    if (LowId = 'conventions') or (LowId = 'syntax') then
      Score := Score + 1.0; // These are critical for correct code generation
  end;

  Result := Score;
end;

function TRAGEngine.BuildMatchReasons(DocIndex: Integer; const Analysis: TRAGQueryAnalysis): String;
var
  Doc: TRAGDocument;
  Parts: TList<String>;
begin
  Doc := FDocuments[DocIndex];
  Parts := TList<String>.Create();
  try
    // Check tag matches
    for var KW in Analysis.Keywords do
      for var Tag in Doc.Tags do
        if NormalizeTag(Tag) = KW then
        begin
          Parts.Add('tag:' + KW);
          Break;
        end;

    // Check function matches
    for var FN in Analysis.FunctionNames do
      if ArrayContains(Doc.Functions, FN) then
        Parts.Add('func:' + FN);

    // Check library hints
    for var Hint in Analysis.LibraryHints do
      if LowerCase(Hint) = LowerCase(Doc.Id) then
        Parts.Add('explicit');

    // Check intent match
    if Analysis.Intent <> '' then
    begin
      if Doc.Subcategory <> '' then
        Parts.Add('intent:' + Analysis.Intent + '→' + Doc.Subcategory);
    end;

    if Parts.Count = 0 then
      Result := 'dependency'
    else
      Result := String.Join(', ', Parts.ToArray);
  finally
    Parts.Free();
  end;
end;

{ ============================================================================
  DEPENDENCY RESOLUTION
  ============================================================================ }

procedure TRAGEngine.ResolveDependencies(Selected: TList<Integer>);
var
  Queue: TList<Integer>;
  DepId: String;
  DepIdx: Integer;
begin
  // Build a queue of dependencies to check
  Queue := TList<Integer>.Create();
  try
    // Seed with current selection
    for var Idx in Selected do
      Queue.Add(Idx);

    var I := 0;
    while I < Queue.Count do
    begin
      var Doc := FDocuments[Queue[I]];
      for var Dep in Doc.Depends do
      begin
        DepId := LowerCase(Dep);
        if FDocById.TryGetValue(DepId, DepIdx) then
        begin
          if not Selected.Contains(DepIdx) then
          begin
            // Add dependency at the beginning (foundational docs first)
            Selected.Insert(0, DepIdx);
            Queue.Add(DepIdx); // Check this doc's dependencies too
          end;
        end;
      end;
      Inc(I);
    end;
  finally
    Queue.Free();
  end;
end;

{ ============================================================================
  CONTENT LOADING AND TRUNCATION
  ============================================================================ }

function TRAGEngine.LoadDocumentContent(var Doc: TRAGDocument): String;
var
  FullPath: String;
begin
  if Doc.ContentLoaded and (Doc.Content <> '') then
  begin
    Result := Doc.Content;
    Exit();
  end;

  FullPath := FBasePath + Doc.Path;
  if TFile.Exists(FullPath) then
  begin
    Result := TFile.ReadAllText(FullPath, TEncoding.UTF8);

    // Strip YAML header if present (between --- markers)
    if Result.StartsWith('---') then
    begin
      var EndMarker := Pos('---', Result, 4);
      if EndMarker > 0 then
        Result := Trim(Copy(Result, EndMarker + 3, MaxInt));
    end;

    Doc.Content := Result;
    Doc.ContentLoaded := True;
  end
  else
    Result := '(Document content not found: ' + FullPath + ')';
end;

function TRAGEngine.TruncateContent(const Content: String; MaxTokens: Integer): String;
var
  MaxChars: Integer;
begin
  MaxChars := MaxTokens * RAG_CHARS_PER_TOKEN;
  if Length(Content) <= MaxChars then
    Result := Content
  else
    Result := Copy(Content, 1, MaxChars) + #13#10 + '... (truncated)';
end;

function TRAGEngine.ExtractEssentialSections(const Content: String; MaxTokens: Integer): String;
var
  Lines: TArray<String>;
  Output: TStringList;
  CurrentTokens: Integer;
  InEssentialSection: Boolean;
  MaxChars: Integer;
  Line, TrimmedLine: String;
begin
  // Strategy: Keep headers, quick reference tables, essential patterns,
  // and first N lines of content. Skip verbose descriptions.
  MaxChars := MaxTokens * RAG_CHARS_PER_TOKEN;

  Lines := Content.Split([#13#10, #10]);
  Output := TStringList.Create();
  try
    CurrentTokens := 0;
    InEssentialSection := True;

    for var I := 0 to High(Lines) do
    begin
      Line := Lines[I];
      TrimmedLine := Trim(Line);

      // Always keep headers
      if TrimmedLine.StartsWith('#') then
      begin
        InEssentialSection := True;
        Output.Add(Line);
        CurrentTokens := CurrentTokens + EstimateTokens(Line);
        Continue;
      end;

      // Always keep table rows (function references)
      if TrimmedLine.StartsWith('|') then
      begin
        Output.Add(Line);
        CurrentTokens := CurrentTokens + EstimateTokens(Line);
        if CurrentTokens >= MaxTokens then Break;
        Continue;
      end;

      // Always keep code blocks
      if TrimmedLine.StartsWith('```') or TrimmedLine.StartsWith('''') then
      begin
        InEssentialSection := True;
        Output.Add(Line);
        CurrentTokens := CurrentTokens + EstimateTokens(Line);
        if CurrentTokens >= MaxTokens then Break;
        Continue;
      end;

      // Keep content within essential sections
      if InEssentialSection then
      begin
        Output.Add(Line);
        CurrentTokens := CurrentTokens + EstimateTokens(Line);

        // After a certain amount, skip to next header
        if (TrimmedLine = '') and (CurrentTokens > MaxTokens div 2) then
          InEssentialSection := False;
      end;

      if CurrentTokens >= MaxTokens then Break;
    end;

    if CurrentTokens >= MaxTokens then
      Output.Add('... (truncated for token budget)');

    Result := Output.Text;
  finally
    Output.Free();
  end;
end;

function TRAGEngine.EstimateTokens(const Text: String): Integer;
begin
  if Text = '' then
    Result := 0
  else
    Result := Max(1, Length(Text) div RAG_CHARS_PER_TOKEN);
end;

{ ============================================================================
  DOCUMENT HEADER PARSING
  ============================================================================ }

function TRAGEngine.ParseDocumentHeader(const FilePath: String): TRAGDocument;
var
  Content, HeaderBlock, Line, Key, Value: String;
  Lines: TArray<String>;
  EndMarker: Integer;
begin
  Result := Default(TRAGDocument);

  Content := TFile.ReadAllText(FilePath, TEncoding.UTF8);
  if not Content.StartsWith('---') then
  begin
    // No YAML header — generate minimal metadata from filename
    Result.Id := LowerCase(ChangeFileExt(ExtractFileName(FilePath), ''));
    Result.Title := Result.Id;
    Result.Category := RAG_CAT_LIBRARY;
    Result.Tags := TArray<String>.Create(Result.Id);
    Exit();
  end;

  // Extract header block between --- markers
  EndMarker := Pos('---', Content, 4);
  if EndMarker <= 0 then Exit();

  HeaderBlock := Copy(Content, 4, EndMarker - 4);
  Lines := HeaderBlock.Split([#13#10, #10]);

  for var I := 0 to High(Lines) do
  begin
    Line := Trim(Lines[I]);
    if Line = '' then Continue;

    var ColonPos := Pos(':', Line);
    if ColonPos <= 0 then Continue;

    Key := Trim(LowerCase(Copy(Line, 1, ColonPos - 1)));
    Value := Trim(Copy(Line, ColonPos + 1, MaxInt));

    if Key = 'id' then
      Result.Id := Value
    else if Key = 'title' then
      Result.Title := Value
    else if Key = 'category' then
      Result.Category := LowerCase(Value)
    else if Key = 'subcategory' then
      Result.Subcategory := LowerCase(Value)
    else if Key = 'tags' then
      Result.Tags := SplitCSV(Value)
    else if Key = 'functions' then
      Result.Functions := SplitCSV(Value)
    else if Key = 'depends' then
      Result.Depends := SplitCSV(Value)
    else if Key = 'complexity' then
      Result.Complexity := LowerCase(Value)
    else if Key = 'platform' then
      Result.Platform := LowerCase(Value)
    else if Key = 'summary' then
      Result.Summary := Value;
  end;

  // Auto-generate ID from filename if missing
  if Result.Id = '' then
    Result.Id := LowerCase(ChangeFileExt(ExtractFileName(FilePath), ''));
end;

{ ============================================================================
  INDEX SERIALIZATION
  ============================================================================ }

function TRAGEngine.DocumentToJSON(const Doc: TRAGDocument): TJSONObject;
var
  TagsArr, FuncsArr, DepsArr: TJSONArray;
begin
  Result := TJSONObject.Create();
  Result.AddPair('id', Doc.Id);
  Result.AddPair('path', Doc.Path);
  Result.AddPair('title', Doc.Title);
  Result.AddPair('category', Doc.Category);
  Result.AddPair('subcategory', Doc.Subcategory);
  Result.AddPair('complexity', Doc.Complexity);
  Result.AddPair('platform', Doc.Platform);
  Result.AddPair('summary', Doc.Summary);
  Result.AddPair('size_bytes', TJSONNumber.Create(Doc.SizeBytes));
  Result.AddPair('token_estimate', TJSONNumber.Create(Doc.TokenEstimate));

  TagsArr := TJSONArray.Create();
  for var T in Doc.Tags do
    TagsArr.Add(T);
  Result.AddPair('tags', TagsArr);

  FuncsArr := TJSONArray.Create();
  for var F in Doc.Functions do
    FuncsArr.Add(F);
  Result.AddPair('functions', FuncsArr);

  DepsArr := TJSONArray.Create();
  for var D in Doc.Depends do
    DepsArr.Add(D);
  Result.AddPair('depends', DepsArr);
end;

function TRAGEngine.JSONToDocument(const Obj: TJSONObject): TRAGDocument;

  function GetStr(const Key: String; const Default: String = ''): String;
  var
    V: TJSONValue;
  begin
    V := Obj.GetValue(Key);
    if (V <> nil) and not (V is TJSONNull) then
      Result := V.Value
    else
      Result := Default;
  end;

  function GetInt(const Key: String; Default: Integer = 0): Integer;
  var
    V: TJSONValue;
  begin
    V := Obj.GetValue(Key);
    if (V <> nil) and (V is TJSONNumber) then
      Result := TJSONNumber(V).AsInt
    else
      Result := Default;
  end;

  function GetArray(const Key: String): TArray<String>;
  var
    V: TJSONValue;
    Arr: TJSONArray;
    Items: TList<String>;
  begin
    V := Obj.GetValue(Key);
    if (V <> nil) and (V is TJSONArray) then
    begin
      Arr := TJSONArray(V);
      Items := TList<String>.Create();
      try
        for var I := 0 to Arr.Count - 1 do
          Items.Add(Arr.Items[I].Value);
        Result := Items.ToArray;
      finally
        Items.Free();
      end;
    end
    else
      Result := nil;
  end;

begin
  Result := Default(TRAGDocument);
  Result.Id := GetStr('id');
  Result.Path := GetStr('path');
  Result.Title := GetStr('title');
  Result.Category := GetStr('category');
  Result.Subcategory := GetStr('subcategory');
  Result.Complexity := GetStr('complexity');
  Result.Platform := GetStr('platform');
  Result.Summary := GetStr('summary');
  Result.SizeBytes := GetInt('size_bytes');
  Result.TokenEstimate := GetInt('token_estimate');
  Result.Tags := GetArray('tags');
  Result.Functions := GetArray('functions');
  Result.Depends := GetArray('depends');
  Result.ContentLoaded := False;
  Result.Content := '';
end;

{ ============================================================================
  HELPERS
  ============================================================================ }

function TRAGEngine.NormalizeTag(const Tag: String): String;
begin
  Result := LowerCase(Trim(Tag));
  // Remove trailing/leading punctuation
  while (Result.Length > 0) and (Result[Result.Length] = ',') or (Result[Result.Length] = ';') do
    Result := Copy(Result, 1, Result.Length - 1);
end;

function TRAGEngine.ArrayContains(const Arr: TArray<String>; const Value: String): Boolean;
var
  LV: String;
begin
  Result := False;
  LV := LowerCase(Value);
  for var S in Arr do
    if LowerCase(S) = LV then
    begin
      Result := True;
      Exit();
    end;
end;

function TRAGEngine.SplitCSV(const S: String): TArray<String>;
var
  Parts: TArray<String>;
  Results: TList<String>;
  Trimmed: String;
begin
  // Handle both "a, b, c" and "[a, b, c]" formats
  var Clean := S;
  if Clean.StartsWith('[') then Clean := Copy(Clean, 2, MaxInt);
  if Clean.EndsWith(']') then Clean := Copy(Clean, 1, Length(Clean) - 1);

  Parts := Clean.Split([',']);
  Results := TList<String>.Create();
  try
    for var P in Parts do
    begin
      Trimmed := Trim(P);
      if Trimmed <> '' then
        Results.Add(Trimmed);
    end;
    Result := Results.ToArray;
  finally
    Results.Free();
  end;
end;

{ ============================================================================
  INFORMATION METHODS
  ============================================================================ }

function TRAGEngine.DocumentCount(): Integer;
begin
  Result := FDocuments.Count;
end;

function TRAGEngine.FunctionCount(): Integer;
begin
  Result := FFuncIndex.Count;
end;

function TRAGEngine.ListDocumentIds(): TArray<String>;
var
  Ids: TList<String>;
begin
  Ids := TList<String>.Create();
  try
    for var I := 0 to FDocuments.Count - 1 do
      Ids.Add(FDocuments[I].Id);
    Result := Ids.ToArray;
  finally
    Ids.Free();
  end;
end;

function TRAGEngine.ListTags(): TArray<String>;
var
  Tags: TList<String>;
begin
  Tags := TList<String>.Create();
  try
    for var Pair in FTagIndex do
      Tags.Add(Pair.Key + ' (' + IntToStr(Pair.Value.Count) + ')');
    Tags.Sort;
    Result := Tags.ToArray;
  finally
    Tags.Free();
  end;
end;

function TRAGEngine.ListCategories(): TArray<String>;
var
  Cats: TList<String>;
begin
  Cats := TList<String>.Create();
  try
    for var Pair in FCategoryIndex do
      Cats.Add(Pair.Key + ': ' + IntToStr(Pair.Value.Count) + ' documents');
    Result := Cats.ToArray;
  finally
    Cats.Free();
  end;
end;

function TRAGEngine.GetIndexSummary(): String;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create();
  try
    SB.AppendLine('=== RAG Engine Index Summary ===');
    SB.AppendFormat('Base path: %s', [FBasePath]).AppendLine;
    SB.AppendFormat('Documents: %d', [FDocuments.Count]).AppendLine;
    SB.AppendFormat('Functions indexed: %d', [FFuncIndex.Count]).AppendLine;
    SB.AppendFormat('Tags indexed: %d', [FTagIndex.Count]).AppendLine;
    SB.AppendLine('Categories:');
    for var Cat in ListCategories do
      SB.AppendFormat('  %s', [Cat]).AppendLine;
    SB.AppendFormat('Max tokens: %d', [FMaxTokens]).AppendLine;
    SB.AppendFormat('Index loaded: %s', [BoolToStr(FIndexLoaded, True)]).AppendLine;
    Result := SB.ToString;
  finally
    SB.Free();
  end;
end;

end.

