# OpenRAM Configuration for L2 Unified Cache
# 256KB configuration (can scale to 512KB by doubling instances or using larger SRAM)
# Unified (shared instruction + data), 64-byte cache lines
# 
# Cache organization:
# - Total size: 256KB = 262144 bytes (can be expanded to 512KB)
# - Typical: 8-way or 16-way set associative for L2
# - Cache line: 64 bytes = 512 bits
# - For 8-way: Each way = 256KB / 8 = 32KB = 32768 bytes
# - Number of lines per way: 32768 / 64 = 512 lines
# - Each SRAM stores one cache line (512 bits) × 512 lines

# Technology and output settings
technology_name = "sky130"
output_name = "sram_l2_cache_way"
output_path = "../macros/openram_output"

# SRAM specifications for ONE way of an 8-way L2 cache (256KB total)
# NOTE: Using 64-bit words instead of 512-bit for better OpenRAM compatibility
# You'll need to instantiate 8 of these per way (8 x 64 bits = 512 bits per line)
# For 256KB L2: 8 ways × 8 SRAMs/way = 64 SRAM instances total
# For 512KB L2: 16 ways × 8 SRAMs/way = 128 SRAM instances total
word_size = 64           # 8 bytes = 64 bits (1/8 of cache line)
num_words = 512          # 512 cache lines per way (32KB per way with 8 instances)
num_banks = 1            # Single bank (can use 2 for larger arrays)

# Port configuration
num_rw_ports = 1         # 1 read/write port
num_r_ports = 0          # 0 additional read-only ports
num_w_ports = 0          # 0 additional write-only ports

# Optimization settings
write_size = 8           # Write granularity in bits (byte-level writes)
                         # This gives you 8 write mask bits for byte enables

# Process corner (optional)
# corner = "TT"          # Typical-Typical corner

# NOTE: For 512KB L2 cache, you have two options:
# Option 1: Use 16 instances of this SRAM (16-way × 32KB = 512KB)
# Option 2: Change num_words to 1024 and use 8 instances (8-way × 64KB = 512KB)
