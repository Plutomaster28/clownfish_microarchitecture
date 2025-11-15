# OpenRAM Configuration for L1 Data Cache
# 32KB total, 4-way set associative, 64-byte cache lines
# 
# Cache organization:
# - Total size: 32KB = 32768 bytes
# - 4-way set associative
# - Cache line: 64 bytes = 512 bits
# - Each way: 32KB / 4 = 8KB = 8192 bytes
# - Number of lines per way: 8192 / 64 = 128 lines
# - Each SRAM stores one cache line (512 bits) × 128 lines

# Technology and output settings
technology_name = "sky130"
output_name = "sram_l1_dcache_way"
output_path = "../macros/openram_output"

# SRAM specifications for ONE way of the 4-way cache
# NOTE: Using 64-bit words instead of 512-bit for better OpenRAM compatibility
# You'll need to instantiate 8 of these per way (8 x 64 bits = 512 bits per line)
# So total: 4 ways × 8 SRAMs/way = 32 SRAM instances for full L1 D-cache
word_size = 64           # 8 bytes = 64 bits (1/8 of cache line)
num_words = 128          # 128 cache lines per way
num_banks = 1            # Single bank

# Port configuration
num_rw_ports = 1         # 1 read/write port
num_r_ports = 0          # 0 additional read-only ports
num_w_ports = 0          # 0 additional write-only ports

# Optimization settings
write_size = 8           # Write granularity in bits (byte-level writes)
                         # This gives you 8 write mask bits for byte enables

# Process corner (optional)
# corner = "TT"          # Typical-Typical corner
