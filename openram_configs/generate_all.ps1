# PowerShell script to generate all OpenRAM macros for Clownfish RISC-V processor

# Check if OPENRAM_HOME is set
if (-not $env:OPENRAM_HOME) {
    Write-Host "Error: OPENRAM_HOME environment variable is not set" -ForegroundColor Red
    Write-Host "Please run: `$env:OPENRAM_HOME = 'C:\path\to\OpenRAM\compiler'" -ForegroundColor Yellow
    exit 1
}

# Create output directory
New-Item -ItemType Directory -Force -Path "..\macros\openram_output" | Out-Null

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Generating OpenRAM macros for Clownfish" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Generate L1 Instruction Cache
Write-Host "Generating L1 Instruction Cache SRAM..." -ForegroundColor Yellow
python $env:OPENRAM_HOME\openram.py l1_icache_config.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error generating L1 I-cache" -ForegroundColor Red
    exit 1
}
Write-Host "✓ L1 I-cache generated" -ForegroundColor Green
Write-Host ""

# Generate L1 Data Cache
Write-Host "Generating L1 Data Cache SRAM..." -ForegroundColor Yellow
python $env:OPENRAM_HOME\openram.py l1_dcache_config.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error generating L1 D-cache" -ForegroundColor Red
    exit 1
}
Write-Host "✓ L1 D-cache generated" -ForegroundColor Green
Write-Host ""

# Generate L2 Cache
Write-Host "Generating L2 Unified Cache SRAM..." -ForegroundColor Yellow
python $env:OPENRAM_HOME\openram.py l2_cache_config.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error generating L2 cache" -ForegroundColor Red
    exit 1
}
Write-Host "✓ L2 cache generated" -ForegroundColor Green
Write-Host ""

# Generate TLB
Write-Host "Generating TLB SRAM..." -ForegroundColor Yellow
python $env:OPENRAM_HOME\openram.py tlb_config.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error generating TLB" -ForegroundColor Red
    exit 1
}
Write-Host "✓ TLB generated" -ForegroundColor Green
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "All SRAM macros generated successfully!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated files are in: ..\macros\openram_output\" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the generated .html datasheets"
Write-Host "2. Copy the required files (.v, .lef, .lib, .gds) to your OpenLane project"
Write-Host "3. Update your OpenLane config.json with the macro paths"
