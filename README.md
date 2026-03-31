# Plan9Basic Applet Runner

A minimal open-source host application for the **Plan9Basic interpreter engine** — a
modern, cross-platform BASIC language runtime built with Delphi / FireMonkey (FMX).

This project packages the core interpreter engine together with four foundational
standard libraries and a ready-to-compile FMX host form, making it easy to:

- Embed BASIC scripting into your own Delphi/FMX applications.
- Load, edit, and run `.bas` Plan9Basic scripts interactively.
- Study or fork the interpreter engine for your own BASIC dialect.

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
| `utils/UnitGC.pas` | Garbage collector for non-visual heap objects (arrays, dicts, JSON, etc.). |

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

### Host Application (this folder)

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
└── Libs/
    ├── ArrayLib.pas            ← Standard library: dynamic arrays
    ├── StdLib.pas              ← Standard library: general utilities
    ├── StrLib.pas              ← Standard library: string functions
    ├── SysLib.pas              ← Standard library: system / file I/O
    ├── TimerLib.pas            ← Timer control library (required by exec.pas)
    ├── NumLib.pas              ← Mathematics: trig, log, random, rounding
    ├── DateTimeLib.pas         ← Date and time operations
    ├── JsonLib.pas             ← JSON parse, build, navigate
    ├── ConfigLib.pas           ← INI-style persistent configuration files
    ├── Base64Lib.pas           ← Base64 encode / decode
    └── ZipLib.pas              ← ZIP archive create, extract, list
```

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
  -I.. -I..\utils -I..\Libs
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

## Embedding the Engine in Your Own Application

`TBasicEngine` (defined in `basic.pas`) is designed to be embedded. Here is the
minimal integration pattern:

```pascal
uses
  basic, exec, UnitGC,
  ArrayLib, StdLib, StrLib, SysLib, TimerLib;

// --- Initialisation (e.g. in FormCreate) ---
GC := TGarbageCollector.Create();

Engine := TBasicEngine.Create();
RegisterArrayFuncs(Engine.Functions); // array functions
RegisterStdFuncs(Engine.Functions); // standard utilities
RegisterStrFuncs(Engine.Functions); // string functions
RegisterSysFuncs(Engine.Functions); // system / file I/O
RegisterTimerFuncs(Engine.Functions, Engine, OutputMemo.Lines); // timer callbacks — required
Engine.ScriptTimeOut := 30; // execution time limit (seconds)

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
