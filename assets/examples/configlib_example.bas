' =============================================================================
' Plan9Basic Applet Runner - ConfigLib Example
' Demonstrates: INI-style persistent configuration files
' =============================================================================

PRINTLN "=== ConfigLib - Configuration Library ==="
PRINTLN ""

' --- Determine a writable path and open a config file ---
cfgFile$ = documentspath$() + "applet_settings.ini"
PRINTLN "Config file: "; cfgFile$
PRINTLN ""

cfg# = cfg_open#(cfgFile$)

' --- Write string values ---
PRINTLN "--- Writing Values ---"
cfg# = cfg_set#(cfg#, "App",    "Name",    "My Applet")
cfg# = cfg_set#(cfg#, "App",    "Version", "1.0.0")
cfg# = cfg_set#(cfg#, "App",    "Author",  "André Murta")
cfg# = cfg_set#(cfg#, "Window", "Theme",   "Dark")
cfg# = cfg_set#(cfg#, "Window", "Font",    "Courier New")
cfg# = cfg_setn#(cfg#, "Window", "FontSize", 13)
cfg# = cfg_setn#(cfg#, "Window", "Width",    960)
cfg# = cfg_setn#(cfg#, "Window", "Height",   700)
cfg# = cfg_setb#(cfg#, "Window", "Maximized", 0)
PRINTLN "Values written."
PRINTLN ""

' --- Save to disk ---
cfg_save(cfg#)
PRINTLN "Saved to: "; cfg_filename$(cfg#)
PRINTLN ""

' --- Read values back ---
PRINTLN "--- Reading Values ---"
PRINTLN "Name      = "; cfg_get$(cfg#, "App",    "Name",    "")
PRINTLN "Version   = "; cfg_get$(cfg#, "App",    "Version", "")
PRINTLN "Author    = "; cfg_get$(cfg#, "App",    "Author",  "")
PRINTLN "Theme     = "; cfg_get$(cfg#, "Window", "Theme",   "")
PRINTLN "Font      = "; cfg_get$(cfg#, "Window", "Font",    "")
PRINTLN "Font size = "; cfg_getn(cfg#, "Window", "FontSize", 12)
PRINTLN "Width     = "; cfg_getn(cfg#, "Window", "Width",  800)
PRINTLN "Height    = "; cfg_getn(cfg#, "Window", "Height", 600)
PRINTLN "Maximized = "; cfg_getb(cfg#, "Window", "Maximized", 0)
PRINTLN ""

' --- Section and key inspection ---
PRINTLN "--- Sections & Keys ---"
PRINTLN "Section count  : "; cfg_sectioncount(cfg#)
PRINTLN "Sections       : "; cfg_sections$(cfg#)
PRINTLN "Keys in App    : "; cfg_keys$(cfg#, "App")
PRINTLN "Keys in Window : "; cfg_keys$(cfg#, "Window")
PRINTLN ""

' --- Existence checks ---
PRINTLN "--- Existence Checks ---"
PRINTLN "cfg_exists App/Name    : "; cfg_exists(cfg#, "App",    "Name")
PRINTLN "cfg_exists App/Missing : "; cfg_exists(cfg#, "App",    "Missing")
PRINTLN "cfg_section_exists App : "; cfg_section_exists(cfg#, "App")
PRINTLN "cfg_section_exists X   : "; cfg_section_exists(cfg#, "X")
PRINTLN ""

' --- Default values when key is missing ---
PRINTLN "--- Default Values ---"
PRINTLN "Missing key    = "; cfg_get$(cfg#, "App", "Missing", "default_value")
PRINTLN "Missing number = "; cfg_getn(cfg#, "App", "MissingNum", 99)
PRINTLN ""

PRINTLN "=== ConfigLib Example Complete ==="
