import rv32i_pkg::*;

module pipeline_top #(
    parameter int unsigned INSTR_MEM_DEPTH      = 256,
    parameter int unsigned INSTR_MEM_LATENCY    = 4,  // Cycles from a request being accepted to its response
    parameter string       INSTR_MEM_IMAGE_PATH = DEFAULT_INSTR_MEM_IMAGE_PATH,
    parameter int unsigned ICACHE_NUM_LINES     = 16,
    parameter int unsigned DATA_MEM_DEPTH       = 256,
    parameter string       DATA_MEM_IMAGE_PATH  = DEFAULT_DATA_MEM_IMAGE_PATH
) (
    input logic clk,
    input logic reset
);
    word_t      memory_read_data_raw;
    word_addr_t memory_word_addr;
    logic       memory_write_en;
    word_t      memory_write_data;
    logic [3:0] memory_write_strobe;

    word_t      instruction_addr;
    word_t      instruction;
    logic       instruction_valid;

    // Instruction cache controller <-> instruction cache
    word_addr_t icache_lookup_word_addr;
    logic       icache_hit;
    word_t      icache_lookup_data;
    logic       icache_fill_en;
    word_addr_t icache_fill_word_addr;
    word_t      icache_fill_data;

    // Instruction cache controller <-> instruction memory
    logic       instr_mem_request_valid;
    logic       instr_mem_request_ready;
    word_addr_t instr_mem_request_word_addr;
    logic       instr_mem_response_valid;
    word_t      instr_mem_response_data;

    pipeline_core u_core (
        .clk                 (clk),
        .reset               (reset),
        .memory_read_data_raw(memory_read_data_raw),
        .memory_word_addr    (memory_word_addr),
        .memory_write_en     (memory_write_en),
        .memory_write_data   (memory_write_data),
        .memory_write_strobe (memory_write_strobe),
        .instruction_addr    (instruction_addr),
        .instruction         (instruction),
        .instruction_valid   (instruction_valid)
    );

    pipeline_icache_controller u_icache_controller (
        .clk                     (clk),
        .reset                   (reset),
        .fetch_addr              (instruction_addr),
        .instruction             (instruction),
        .instruction_valid       (instruction_valid),
        .cache_lookup_word_addr  (icache_lookup_word_addr),
        .cache_hit               (icache_hit),
        .cache_lookup_data       (icache_lookup_data),
        .cache_fill_en           (icache_fill_en),
        .cache_fill_word_addr    (icache_fill_word_addr),
        .cache_fill_data         (icache_fill_data),
        .memory_request_valid    (instr_mem_request_valid),
        .memory_request_ready    (instr_mem_request_ready),
        .memory_request_word_addr(instr_mem_request_word_addr),
        .memory_response_valid   (instr_mem_response_valid),
        .memory_response_data    (instr_mem_response_data)
    );

    pipeline_icache #(
        .NUM_LINES(ICACHE_NUM_LINES)
    ) u_icache (
        .clk             (clk),
        .reset           (reset),
        .lookup_word_addr(icache_lookup_word_addr),
        .hit             (icache_hit),
        .lookup_data     (icache_lookup_data),
        .fill_en         (icache_fill_en),
        .fill_word_addr  (icache_fill_word_addr),
        .fill_data       (icache_fill_data)
    );

    pipeline_instruction_memory #(
        .DEPTH     (INSTR_MEM_DEPTH),
        .LATENCY   (INSTR_MEM_LATENCY),
        .IMAGE_PATH(INSTR_MEM_IMAGE_PATH)
    ) u_instruction_memory (
        .clk              (clk),
        .reset            (reset),
        .request_valid    (instr_mem_request_valid),
        .request_ready    (instr_mem_request_ready),
        .request_word_addr(instr_mem_request_word_addr),
        .response_valid   (instr_mem_response_valid),
        .response_data    (instr_mem_response_data)
    );

    data_memory #(
        .DEPTH     (DATA_MEM_DEPTH),
        .IMAGE_PATH(DATA_MEM_IMAGE_PATH)
    ) u_data_memory (
        .clk         (clk),
        .word_addr   (memory_word_addr),
        .write_en    (memory_write_en),
        .write_data  (memory_write_data),
        .write_strobe(memory_write_strobe),
        .read_data   (memory_read_data_raw)
    );
endmodule
