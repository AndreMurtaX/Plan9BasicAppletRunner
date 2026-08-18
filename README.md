# Plan9Basic Applet Runner

A minimal open-source host application for the **Plan9Basic interpreter engine** — a
modern, cross-platform BASIC language runtime built with Delphi / FireMonkey (FMX).

This project packages the core interpreter engine together with a growing set of
standard libraries and a ready-to-compile FMX host form, making it easy to:

- Embed BASIC scripting into your own Delphi/FMX applications.
- Load, edit, and run `.bas` Plan9Basic scripts interactively.
- Perform HTTP requests, query AI providers, and build RAG pipelines — all from BASIC.
- Study or fork the interpreter engine for your own BASIC dialect.

---

## Building

The interpreter core and the shared standard library live in a separate
repository, [Plan9BasicEngine](https://github.com/AndreMurtaX/Plan9BasicEngine),
and are pulled in as a git submodule under `engine/`. **Clone recursively**, or
the `engine/` folder arrives empty and the build fails on the first unit:

```bash
git clone --recurse-submodules https://github.com/AndreMurtaX/Plan9BasicAppletRunner.git
```

Already cloned without it? Fix an existing checkout with:

```bash
git submodule update --init --recursive
```

Then open `Plan9BasicApplet.dproj` in RAD Studio and build, or build from the
command line:

```bash
dcc64 Plan9BasicApplet.dpr
```

No search paths or environment setup are needed: every unit is referenced with
its path from the `.dpr`, including the ones inside `engine/`.

---

## Screenshots

| Windows 64-bit | Linux Ubuntu 22.04 (64-bit) | Android (64-bit) |
|:-:|:-:|:-:|
| ![Plan9Basic Applet Runner on Windows](assets/images/P9B%20Windows.png) | ![Plan9Basic Applet Runner on Ubuntu 22.04](assets/images/P9B%20Ubuntu22.04.png) | ![Plan9Basic Applet Runner on Android](assets/images/P9B%20Android64.png) |

---

## License

This project is released under the **MIT License** — one of the most permissive
open-source licenses available.

You are free to **use, copy, modify, merge, publish, distribute, sublicense,
and/or sell** copies of this software in both open-source and commercial products.
The only requirement is that the copyright notice and license text are preserved
in all copies or substantial portions of the Software.

See [LICENSE](LICENSE) for the full text.

> **Why MIT?**
> The goal is maximum freedom. MIT imposes no copyleft obligations — you can
> integrate the engine into proprietary software without any restrictions.
> It is the closest practical equivalent to placing code in the public domain
> while still protecting against liability.

---

## Requirements

| Tool | Notes |
|------|-------|
| **RAD Studio** or **Delphi** | FireMonkey (FMX) required. Version 10.3 Rio or later recommended. |
| **Target platform** | Windows, macOS, Linux, iOS, Android — all FireMonkey targets are supported. |
| **External dependencies** | None beyond the standard RAD Studio / FMX RTL. |

---

## Included Components

### Interpreter Engine

| File | Description |
|------|-------------|
| `basic.pas` | `TBasicEngine` — top-level interface between a host application and the language runtime. |
| `lexer.pas` | Tokenizer — converts BASIC source text into a stream of lexical tokens. |
| `parser.pas` | Parser — validates syntax and emits intermediate postfix code. |
| `exec.pas` | Stack machine VM — executes the compiled postfix program. |
| `UnitUtils.pas` | Utility helpers shared across all engine components. |
| `utils/UnitGC.pas` | Garbage collector for non-visual heap objects (arrays, dicts, JSON, HTTP clients, AI clients, etc.). |

### Standard Libraries

| File | Description |
|------|-------------|
| `Libs/ArrayLib.pas` | Dynamic arrays with 1-based indexing, up to 10 dimensions. Numeric, string, and pointer variants. |
| `Libs/StdLib.pas` | General-purpose utilities: type conversion, formatting, pointer helpers. |
| `Libs/StrLib.pas` | 47+ string manipulation functions (search, replace, split, encoding, clipboard…). |
| `Libs/SysLib.pas` | File system, environment variables, and platform operations. |
| `Libs/TimerLib.pas` | Timer control: interval timers with `OnTimer` callbacks. Required by the engine for breakpoint handling. |
| `Libs/NumLib.pas` | Mathematics: trigonometry, logarithms, rounding, random numbers, abs, sign, min, max. |
| `Libs/DateTimeLib.pas` | Date and time: current date/time, formatting, parsing, and date arithmetic. |
| `Libs/JsonLib.pas` | JSON support: parse, build, and navigate JSON objects and arrays. GC-tracked. |
| `Libs/ConfigLib.pas` | Persistent INI-style configuration files. Cross-platform storage locations. |
| `Libs/Base64Lib.pas` | Base64 encoding and decoding for strings and binary files. URL-safe variant included. |
| `Libs/ZipLib.pas` | ZIP archive operations: create, open, add files, extract, and list archive contents. |
| `Libs/HttpLib.pas` | **NEW** — Full HTTP client: GET, POST, PUT, DELETE, PATCH, HEAD. Custom headers, cookies, Basic/Bearer auth, form data, query parameters, URL/HTML encoding, timeout control, and status-code helpers. 82 functions. Cross-platform synchronous API. |
| `Libs/PlatformInfoLib.pas` | **NEW** — OS and platform detection: name, version (major, minor, build), service pack, architecture, and version-check helpers. |

### AI Libraries *(new — `Libs/AI/` subfolder)*

| File | Description |
|------|-------------|
| `Libs/AI/AILib.pas` | **NEW** — Provider-agnostic AI transport layer. Supports Anthropic (Claude), OpenAI (GPT), Google (Gemini), Mistral, Groq, DeepSeek, xAI/Grok, Perplexity, Together AI, Fireworks AI, OpenRouter, local Ollama, and LM Studio — all through a single unified interface. Includes synchronous completion, multi-turn conversation management, streaming (SSE), and tool-use support. 49 functions. |
| `Libs/AI/RAGLib.pas` | **NEW** — Plan9Basic bindings for the RAG engine. Lets scripts create a knowledge-base index, retrieve relevant documents by query, look up documents by tag or function name, and feed the results directly into an AI prompt. 13 functions. |
| `Libs/AI/RAGEngine.pas` | **NEW** — Pure-Delphi Retrieval-Augmented Generation engine. No external dependencies, no vector databases, no embeddings API, no Python required. Uses multi-signal keyword scoring (tag, title, function-name, category, and dependency signals) with token-budget management to select the most relevant documents for a given query. Consumed internally by `RAGLib.pas`. |

### Host Application

| File | Description |
|------|-------------|
| `AppletRunner.pas` | Minimal FMX host form — load, edit, and run `.bas` scripts with a single click. |
| `Plan9BasicApplet.dpr` | Delphi project file. |

---

## Project Structure

The repository is fully self-contained — every file needed to compile is included.

```
Plan9Basic-AppletRunner/
├── LICENSE
├── README.md
├── Plan9BasicApplet.dproj      ← Open this in RAD Studio to build
├── Plan9BasicApplet.dpr        ← RAD Studio main project file
├── AppletRunner.pas            ← Host application form
│
├── basic.pas                   ← Engine: main interface (TBasicEngine)
├── lexer.pas                   ← Engine: tokenizer
├── parser.pas                  ← Engine: parser / code generator
├── exec.pas                    ← Engine: stack machine VM
├── UnitUtils.pas               ← Engine: shared utilities
│
├── utils/
│   └── UnitGC.pas              ← Engine: garbage collector
│
├── Libs/
│   ├── ArrayLib.pas            ← Standard library: dynamic arrays
│   ├── StdLib.pas              ← Standard library: general utilities
│   ├── StrLib.pas              ← Standard library: string functions
│   ├── SysLib.pas              ← Standard library: system / file I/O
│   ├── TimerLib.pas            ← Timer control library (required by exec.pas)
│   ├── NumLib.pas              ← Mathematics: trig, log, random, rounding
│   ├── DateTimeLib.pas         ← Date and time operations
│   ├── JsonLib.pas             ← JSON parse, build, navigate
│   ├── ConfigLib.pas           ← INI-style persistent configuration files
│   ├── Base64Lib.pas           ← Base64 encode / decode
│   ├── ZipLib.pas              ← ZIP archive create, extract, list
│   ├── HttpLib.pas             ← NEW: HTTP client (82 functions)
│   ├── PlatformInfoLib.pas     ← NEW: OS / platform detection
│   └── AI/
│       ├── AILib.pas           ← NEW: AI provider transport layer (49 functions)
│       ├── RAGLib.pas          ← NEW: RAG engine Plan9Basic bindings (13 functions)
│       └── RAGEngine.pas       ← NEW: Pure-Delphi RAG engine (no external deps)
│
└── assets/
    ├── images/                 ← Screenshots used in this README
    └── examples/               ← Ready-to-run example applets (see below)
```

---

## Example Applets

The `assets/examples/` folder contains ready-to-run `.bas` scripts that demonstrate
both the language and the standard libraries. Load any of them in the Applet Runner
and press **Run ▶** to try them out.

### General Language & Library Tests

| File | What it demonstrates |
|------|----------------------|
| `stdlib_test.bas` | Type conversion, formatting, and pointer helpers (StdLib) |
| `strlib_test.bas` | String manipulation functions (StrLib) |
| `numlib_test.bas` | Mathematics and rounding functions (NumLib) |
| `datetimelib_test.bas` | Date and time operations (DateTimeLib) |
| `syslib_test.bas` | File system and environment operations (SysLib) |
| `ArrayLib_Tests.bas` | Multi-dimensional dynamic arrays (ArrayLib) |
| `json_test.bas` | Building, parsing, and navigating JSON (JsonLib) |
| `Base64_quick_test.bas` | Quick Base64 encode/decode round-trip (Base64Lib) |
| `Base64Lib_tests.bas` | Full Base64 test suite including URL-safe variant |
| `test_ziplib.bas` | ZIP archive creation, listing, and extraction (ZipLib) |
| `configlib_example.bas` | INI-style persistent configuration files (ConfigLib) |
| `string_formatter.bas` | Formatted output and string building patterns |
| `do_loop_test.bas` | Loop constructs and control-flow patterns |

### HTTP Client Examples *(HttpLib — new)*

| File | What it demonstrates |
|------|----------------------|
| `HttpLib_SimpleTest.bas` | The simplest possible GET request in one line |
| `HttpLib_QuickTest.bas` | Ten-test validation covering GET, POST, PUT, DELETE, auth, params, and URL encoding |
| `HttpLib_MethodsTest.bas` | Every HTTP method (GET, POST, PUT, DELETE, PATCH, HEAD) side-by-side |
| `HttpLib_Tests.bas` | Full 22-test suite: client lifecycle, custom headers, cookies, form data (URL-encoded and multipart), Basic/Bearer auth, response headers, status codes, timeouts, User-Agent, and error handling — tested against [httpbin.org](https://httpbin.org) |
| `HttpLib_DebugTest.bas` | Verbose request/response inspection for debugging connectivity issues |

### AI Examples *(AILib — new)*

| File | What it demonstrates |
|------|----------------------|
| `hello_ai.bas` | The absolute minimum to call an AI and get a response — one client, one question, one answer. Works out-of-the-box with local [Ollama](https://ollama.com) (no API key needed), or switch `PROVIDER$` to `"anthropic"`, `"openai"`, `"groq"`, `"deepseek"`, or any other supported cloud provider |

---

## Building

### From the RAD Studio IDE

1. Open **RAD Studio**.
2. Choose **File → Open** and select `Plan9BasicApplet.dpr`.
3. RAD Studio will generate the companion `.dproj` file automatically.
4. Select your target platform (Win32, Win64, macOS, Linux, iOS, Android).
5. Press **F9** to build and run.

### From the Command Line (Win64)

```bat
dcc64 Plan9BasicApplet.dpr ^
  -NSSystem;FMX;Data ^
  -I.. -I..\utils -I..\Libs -I..\Libs\AI
```

### Platform notes

| Platform | Load / Save behaviour |
|----------|-----------------------|
| **Windows, macOS, Linux** | Native file picker dialogs (`TOpenDialog` / `TSaveDialog`). |
| **iOS, Android** | `TDialogService.InputQuery` prompts for a filename. Files are read from and written to the app's Documents folder (`TPath.GetDocumentsPath`). Deploy `.bas` scripts to the device before loading, or type/paste the script directly into the editor and save it first. |

The `P9B_DESKTOP` conditional in `AppletRunner.pas` is set automatically at
compile time — no manual changes are needed when switching target platforms.

---

## Quick Start: Writing a Plan9Basic Script

```basic
' --- Hello World ---
PRINTLN "Hello, World!"

' --- Variables and loops ---
LET name$ = "Plan9Basic"
FOR i = 1 TO 3
  PRINTLN name$ + " — iteration: " + STR$(i)
NEXT i

' --- String library ---
LET s$ = UCase$("hello world")
PRINTLN s$

' --- Array library ---
arr# = dim#(10)
FOR i = 1 TO 10
  arr#[i] = i * i
NEXT i
PRINTLN "5 squared = "; arr#[5]

' --- System library ---
PRINTLN "Documents directory: " + DocumentsPath$()
```

Save the file with a `.bas` extension, click **Load** in the Applet Runner, then
press **Run ▶**.

---

## Quick Start: HTTP Requests

```basic
' --- Simple one-liner GET ---
LET response$ = http_simpleget$("https://httpbin.org/get")
PRINTLN response$

' --- Client-based workflow ---
LET client# = http_client#("https://api.example.com")
LET client# = http_header#(client#, "Authorization", "Bearer " + myToken$)
LET client# = http_param#(client#, "page", "1")
LET response$ = http_get$(client#, "/items")

IF http_ok(client#) <> 0 THEN
  PRINTLN "Status: " + STR$(http_status(client#))
  PRINTLN response$
ELSE
  PRINTLN "Error: " + http_errormsg$()
END IF
LET x = http_free(client#)
```

---

## Quick Start: AI Integration

```basic
' Works with local Ollama (free, no API key):
'   1. Install Ollama from https://ollama.com
'   2. Run: ollama pull llama3.2
'   3. Run this script as-is

LET PROVIDER$ = "ollama"   ' or "anthropic", "openai", "groq", "deepseek" …
LET APIKEY$   = ""         ' leave empty for Ollama; paste your key for cloud providers
LET MODEL$    = "llama3.2"

LET ai# = ai_client#(PROVIDER$, APIKEY$)
LET ai# = ai_model#(ai#, MODEL$)
LET response$ = ai_complete$(ai#, "Explain recursion in one sentence.")

IF ai_ok(ai#) = 1 THEN
  PRINTLN response$
ELSE
  PRINTLN "Error: " + ai_errormsg$()
END IF
LET x = ai_free(ai#)
```

See `assets/examples/hello_ai.bas` for the full annotated version and instructions
for switching between providers.

---

## Embedding the Engine in Your Own Application

`TBasicEngine` (defined in `basic.pas`) is designed to be embedded. Here is the
minimal integration pattern:

```pascal
uses
  basic, exec, UnitGC,
  ArrayLib, StdLib, StrLib, SysLib, TimerLib,
  HttpLib, PlatformInfoLib,
  AILib, RAGLib;

// --- Initialisation (e.g. in FormCreate) ---
GC := TGarbageCollector.Create();

Engine := TBasicEngine.Create();
RegisterArrayFuncs(Engine.Functions);
RegisterStdFuncs(Engine.Functions);
RegisterStrFuncs(Engine.Functions);
RegisterSysFuncs(Engine.Functions);
RegisterTimerFuncs(Engine.Functions, Engine, OutputMemo.Lines); // required
RegisterHttpFuncs(Engine.Functions, Engine, OutputMemo.Lines);
RegisterPlatformInfoFuncs(Engine.Functions);
RegisterAIFuncs(Engine.Functions, Engine, OutputMemo.Lines);
RegisterRAGFuncs(Engine.Functions);
Engine.ScriptTimeOut := 30;

// --- Compile and run ---
if Engine.Compile(MyMemo.Lines) = 0 then
  Engine.ExecuteProgram(OutputMemo.Lines)
else
  ShowMessage('Line ' + IntToStr(Engine.ErrorLine) + ': ' + Engine.ErrorMessage);

// --- Clean up (e.g. in FormDestroy) ---
FreeAndNil(Engine);
FreeAndNil(GC);
```

### Key `TBasicEngine` Members

| Member | Kind | Description |
|--------|------|-------------|
| `Compile(source: TStrings): Integer` | Function | Returns 0 on success, error count otherwise. |
| `ExecuteProgram(stdout: TStrings)` | Procedure | Runs the compiled program; PRINT output appended to `stdout`. |
| `Stop()` | Procedure | Signals the VM to halt at the next instruction. |
| `ErrorLine` | Property | 1-based line number of the last compile error. |
| `ErrorMessage` | Property | Human-readable description of the last compile error. |
| `Functions` | Property | `TFunctionsDictionary` — pass to `RegisterXxxFuncs()` calls. |
| `ScriptTimeOut` | Property | Maximum execution time in seconds (default: 30). |
| `OnPrintOutput` | Event | Fires for each PRINT; `IsClear = True` means CLS was called. |

---

## About Plan9Basic

Plan9Basic is a modern BASIC language interpreter designed for embedding in
Delphi / FireMonkey applications. It draws inspiration from classic BASIC dialects
while offering structured control flow (`IF/ELSEIF/ENDIF`, `FOR/NEXT`,
`WHILE/ENDWHILE`, `REPEAT/UNTIL`, `SELECT/CASE`), user-defined functions,
and a rich standard library system.

The engine compiles source code to a compact postfix intermediate representation
and executes it on a stack machine VM, making it fast and easy to extend.

### The Plan9Basic Website

The full Plan9Basic language — documentation, interactive examples, and the
complete online BASIC environment — lives at **[plan9basic.com](https://plan9basic.com)**.

**This repository is the heart of that project.** The interpreter engine published
here (`basic.pas`, `lexer.pas`, `parser.pas`, `exec.pas`) is the exact same engine
that powers the Plan9Basic website. Every language feature documented there —
every statement, operator, built-in function, and library call — can be reproduced
locally by building this project. If it runs on the website, it runs here.

In practical terms this means:

- Any script you write and test on the website compiles and runs identically
  from this open-source runner.
- Any script you build and debug locally can be copied directly to the website
  without modification.
- Embedding this engine in your own application gives you the same language
  capabilities that the website offers, ready to be extended in any direction
  you choose.

---

## Contributing

Contributions are welcome!

- **Bug reports**: open a GitHub Issue with a minimal reproducing script.
- **Pull requests**: please keep changes focused; add an example script when
  fixing a language bug.
- **New library functions**: follow the `Register*Funcs(Lib: TFunctionsDictionary)`
  pattern used by the existing libraries.

---

## Found a Bug? Have a Brilliant Idea? (Or Just Want to Say Hello?)

So you dug through the source code, found something that looks suspiciously wrong,
or thought of a feature so obviously missing that you can't believe it isn't there
yet — congratulations, you are now officially a Plan9Basic contributor in spirit!

Feel free to drop an email to **[plan9basic@plan9basic.com](mailto:plan9basic@plan9basic.com)**
describing what you found or what you'd like to see. Bug reports, improvement
suggestions, and creative ideas are all genuinely appreciated.

Fair warning: responses arrive at the speed of available free time, which in the
life of a solo developer can range from *"reply in 24 hours"* to *"reply after I
finish this one last feature that turned into a three-week rabbit hole."*
Rest assured, every message is read and nothing gets lost — it just occasionally
gets read at 11 pm with a coffee that should have been a decaf.

Your patience is appreciated almost as much as your bug reports. 🙂

---

*Released under the [MIT License](LICENSE).*
