// ============================================================================
// RISC-V Instruction Opcodes and Functions
// ============================================================================
// RV32IMAF Instruction Encoding
// ============================================================================

`ifndef RISCV_OPCODES_VH
`define RISCV_OPCODES_VH

// ============================================================================
// Base Opcodes (bits [6:0])
// ============================================================================
`define OPCODE_LOAD         7'b0000011
`define OPCODE_LOAD_FP      7'b0000111
`define OPCODE_MISC_MEM     7'b0001111  // FENCE, FENCE.I
`define OPCODE_OP_IMM       7'b0010011  // ADDI, SLTI, XORI, etc.
`define OPCODE_AUIPC        7'b0010111
`define OPCODE_STORE        7'b0100011
`define OPCODE_STORE_FP     7'b0100111
`define OPCODE_AMO          7'b0101111  // Atomic operations
`define OPCODE_OP           7'b0110011  // ADD, SUB, SLL, etc.
`define OPCODE_LUI          7'b0110111
`define OPCODE_OP_FP        7'b1010011  // Floating-point operations
`define OPCODE_BRANCH       7'b1100011
`define OPCODE_JALR         7'b1100111
`define OPCODE_JAL          7'b1101111
`define OPCODE_SYSTEM       7'b1110011  // ECALL, EBREAK, CSR

// ============================================================================
// Function3 Codes (bits [14:12])
// ============================================================================
// LOAD
`define FUNCT3_LB           3'b000
`define FUNCT3_LH           3'b001
`define FUNCT3_LW           3'b010
`define FUNCT3_LBU          3'b100
`define FUNCT3_LHU          3'b101

// STORE
`define FUNCT3_SB           3'b000
`define FUNCT3_SH           3'b001
`define FUNCT3_SW           3'b010

// BRANCH
`define FUNCT3_BEQ          3'b000
`define FUNCT3_BNE          3'b001
`define FUNCT3_BLT          3'b100
`define FUNCT3_BGE          3'b101
`define FUNCT3_BLTU         3'b110
`define FUNCT3_BGEU         3'b111

// OP-IMM
`define FUNCT3_ADDI         3'b000
`define FUNCT3_SLTI         3'b010
`define FUNCT3_SLTIU        3'b011
`define FUNCT3_XORI         3'b100
`define FUNCT3_ORI          3'b110
`define FUNCT3_ANDI         3'b111
`define FUNCT3_SLLI         3'b001
`define FUNCT3_SRLI_SRAI    3'b101

// OP
`define FUNCT3_ADD_SUB      3'b000
`define FUNCT3_SLL          3'b001
`define FUNCT3_SLT          3'b010
`define FUNCT3_SLTU         3'b011
`define FUNCT3_XOR          3'b100
`define FUNCT3_SRL_SRA      3'b101
`define FUNCT3_OR           3'b110
`define FUNCT3_AND          3'b111

// MUL/DIV (M extension)
`define FUNCT3_MUL          3'b000
`define FUNCT3_MULH         3'b001
`define FUNCT3_MULHSU       3'b010
`define FUNCT3_MULHU        3'b011
`define FUNCT3_DIV          3'b100
`define FUNCT3_DIVU         3'b101
`define FUNCT3_REM          3'b110
`define FUNCT3_REMU         3'b111

// SYSTEM
`define FUNCT3_PRIV         3'b000  // ECALL, EBREAK, MRET, SRET, WFI
`define FUNCT3_CSRRW        3'b001
`define FUNCT3_CSRRS        3'b010
`define FUNCT3_CSRRC        3'b011
`define FUNCT3_CSRRWI       3'b101
`define FUNCT3_CSRRSI       3'b110
`define FUNCT3_CSRRCI       3'b111

// FENCE
`define FUNCT3_FENCE        3'b000
`define FUNCT3_FENCE_I      3'b001

// ============================================================================
// Function7 Codes (bits [31:25])
// ============================================================================
`define FUNCT7_ADD          7'b0000000
`define FUNCT7_SUB          7'b0100000
`define FUNCT7_SRL          7'b0000000
`define FUNCT7_SRA          7'b0100000
`define FUNCT7_MULDIV       7'b0000001  // M extension

// ============================================================================
// Atomic Operation Codes (bits [31:27] for AMO)
// ============================================================================
`define AMO_LR              5'b00010
`define AMO_SC              5'b00011
`define AMO_AMOSWAP         5'b00001
`define AMO_AMOADD          5'b00000
`define AMO_AMOXOR          5'b00100
`define AMO_AMOAND          5'b01100
`define AMO_AMOOR           5'b01000
`define AMO_AMOMIN          5'b10000
`define AMO_AMOMAX          5'b10100
`define AMO_AMOMINU         5'b11000
`define AMO_AMOMAXU         5'b11100

// ============================================================================
// Floating-Point Function Codes
// ============================================================================
// FP Load/Store width (funct3)
`define FUNCT3_FLW          3'b010
`define FUNCT3_FSW          3'b010

// FP Operations (funct7 for OPCODE_OP_FP)
`define FUNCT7_FADD_S       7'b0000000
`define FUNCT7_FSUB_S       7'b0000100
`define FUNCT7_FMUL_S       7'b0001000
`define FUNCT7_FDIV_S       7'b0001100
`define FUNCT7_FSQRT_S      7'b0101100
`define FUNCT7_FSGNJ_S      7'b0010000
`define FUNCT7_FMIN_FMAX_S  7'b0010100
`define FUNCT7_FCVT_W_S     7'b1100000
`define FUNCT7_FMV_X_W      7'b1110000
`define FUNCT7_FCMP_S       7'b1010000
`define FUNCT7_FCVT_S_W     7'b1101000
`define FUNCT7_FMV_W_X      7'b1111000

// FP rounding modes (funct3 for FP ops)
`define RM_RNE              3'b000  // Round to nearest, ties to even
`define RM_RTZ              3'b001  // Round towards zero
`define RM_RDN              3'b010  // Round down
`define RM_RUP              3'b011  // Round up
`define RM_RMM              3'b100  // Round to nearest, ties to max magnitude
`define RM_DYN              3'b111  // Dynamic rounding mode

// ============================================================================
// System Instructions (funct12 for FUNCT3_PRIV)
// ============================================================================
`define FUNCT12_ECALL       12'h000
`define FUNCT12_EBREAK      12'h001
`define FUNCT12_URET        12'h002
`define FUNCT12_SRET        12'h102
`define FUNCT12_MRET        12'h302
`define FUNCT12_WFI         12'h105
`define FUNCT12_SFENCE_VMA  12'h120

// ============================================================================
// ALU Operation Codes (internal)
// ============================================================================
`define ALU_ADD             4'd0
`define ALU_SUB             4'd1
`define ALU_SLL             4'd2
`define ALU_SLT             4'd3
`define ALU_SLTU            4'd4
`define ALU_XOR             4'd5
`define ALU_SRL             4'd6
`define ALU_SRA             4'd7
`define ALU_OR              4'd8
`define ALU_AND             4'd9
`define ALU_NOP             4'd10

`endif // RISCV_OPCODES_VH
