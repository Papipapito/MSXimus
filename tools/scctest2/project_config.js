// project_config.js — scctest2: test de los DOS SCC del MSXnano 60K (build _57)
// ROM Konami SCC (el SCC1 esta en NUESTRO cartucho), MSX2+.

DoClean   = false;
DoCompile = true;
DoMake    = true;
DoPackage = true;
DoDeploy  = false;
DoRun     = false;

ProjName    = "scctest2";
ProjModules = [ ProjName ];
LibModules  = [ "system", "bios", "vdp", "print", "input", "memory", "math" ];

Machine = "2P";              // MSX2+
Target  = "ROM_KONAMI_SCC";  // mapper Konami SCC: el SCC1 es el del cartucho

AppSignature = true;
AppCompany   = "AX";
AppID        = "S2";

Verbose           = true;
CompileComplexity = "Default";
