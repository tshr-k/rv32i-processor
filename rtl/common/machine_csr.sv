import rv32i_pkg::*;

module machine_csr (
    input  logic      clk,
    input  logic      reset,

    // Trap entry
    input  logic      trap_enter,
    input  word_t     trap_pc,
    input  word_t     trap_cause,

    // Software CSR access
    input  csr_addr_t csr_addr,
    output word_t     csr_read_data,
    input  logic      csr_write_en,
    input  word_t     csr_write_data,

    // Machine CSR outputs
    output word_t mepc,
    output word_t mcause,
    output word_t mtvec
);
    localparam csr_addr_t MTVEC_ADDR  = 12'h305;
    localparam csr_addr_t MEPC_ADDR   = 12'h341;
    localparam csr_addr_t MCAUSE_ADDR = 12'h342;

    always_comb begin
        csr_read_data = 32'b0;

        case (csr_addr)
            MTVEC_ADDR:  csr_read_data = mtvec;
            MEPC_ADDR:   csr_read_data = mepc;
            MCAUSE_ADDR: csr_read_data = mcause;
            default:     csr_read_data = '0;  // For now, return 0 for unimplemented CSRs
        endcase
    end

    // CSR storage
    always_ff @(posedge clk) begin  // All writes are forcibly aligned to 4-byte boundaries
        if (reset) begin
            mepc   <= '0;
            mcause <= '0;
            mtvec  <= MTVEC_RESET;
        end else if (trap_enter) begin // Trap entry has priority over software writes
            mepc   <= {trap_pc[31:2], 2'b00};
            mcause <= trap_cause;
        end else if (csr_write_en) begin
            case (csr_addr)
                MTVEC_ADDR:  mtvec  <= {csr_write_data[31:2], 2'b00};  // Only direct mode (MODE = 0) is supported
                MEPC_ADDR:   mepc   <= {csr_write_data[31:2], 2'b00};
                MCAUSE_ADDR: mcause <= csr_write_data;
                default:     ;  // For now, ignore writes to unimplemented CSRs
            endcase
        end
    end
endmodule
