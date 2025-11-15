# OpenRAM Configuration for Translation Lookaside Buffer (TLB)
# 64 entries, typically storing virtual-to-physical address mappings
# 
# TLB entry format (example for 32-bit RISC-V):
# - Virtual Page Number (VPN): 20 bits
# - Physical Page Number (PPN): 20 bits  
# - Flags (Valid, Dirty, Access, User, etc.): ~8 bits
# - Total: ~48 bits per entry (rounded to 64 bits for alignment)

# Technology and output settings
technology_name = "sky130"
output_name = "sram_tlb"
output_path = "../macros/openram_output"

# SRAM specifications for TLB
word_size = 64           # 64 bits per TLB entry
                         # Format: [20-bit VPN | 20-bit PPN | flags]
num_words = 64           # 64 TLB entries as specified
num_banks = 1            # Single bank (TLB is small and fast)

# Port configuration
# TLB typically needs fast parallel lookup
num_rw_ports = 1         # 1 read/write port for updates
num_r_ports = 1          # 1 additional read-only port for concurrent lookups
num_w_ports = 0          # 0 additional write-only ports

# Optimization settings
write_size = 64          # Write full entry at once (no partial writes needed)

# Process corner (optional)
# corner = "TT"          # Typical-Typical corner

# NOTE: In practice, TLBs are often implemented with CAM (Content Addressable Memory)
# for parallel search, but OpenRAM generates standard SRAM. You'll need to implement
# the associative lookup logic in RTL around this SRAM, or use this for a
# simple direct-mapped TLB.
