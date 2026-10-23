import rv32i_pkg::*;

module pipeline_instruction_memory #(
    parameter int unsigned DEPTH      = 256,
    parameter int unsigned LATENCY    = 4,  // Cycles from a request being accepted to its response
    parameter              IMAGE_PATH = DEFAULT_INSTR_MEM_IMAGE_PATH
) (
    input  logic       clk,
    input  logic       reset,

    // Request
    input  logic       request_valid,
    output logic       request_ready,  // Only one request can be outstanding at a time
    input  word_addr_t request_word_addr,

    // Response
    output logic       response_valid,  // Asserted for one cycle, LATENCY cycles after the request was accepted
    output word_t      response_data
);
    word_t instructions [DEPTH-1:0];

    initial begin
        assert (DEPTH >= 2 && (DEPTH & (DEPTH - 1)) == 0)
            else $fatal(1, "DEPTH must be a power of 2 and at least 2.");
        assert (LATENCY >= 1)
            else $fatal(1, "LATENCY must be at least 1.");

        $readmemh(IMAGE_PATH, instructions);
    end

    localparam int unsigned INSTR_ADDR_WIDTH = $clog2(DEPTH);
    localparam int unsigned COUNTER_WIDTH    = $clog2(LATENCY + 1);

    typedef logic [COUNTER_WIDTH-1:0] counter_t;

    counter_t   cycles_remaining;  // Zero when idle
    word_addr_t pending_word_addr;

    assign request_ready  = (cycles_remaining == '0);
    assign response_valid = (cycles_remaining == counter_t'(1));

    // Asynchronous read of the pending request's word
    // Upper address bits are ignored, so out-of-range addresses wrap around
    assign response_data = instructions[pending_word_addr[(INSTR_ADDR_WIDTH+2) - 1 : 2]];

    always_ff @(posedge clk) begin
        if (reset) begin
            cycles_remaining <= '0;
        end else if (request_valid && request_ready) begin
            cycles_remaining  <= counter_t'(LATENCY);
            pending_word_addr <= request_word_addr;
        end else if (cycles_remaining != '0) begin
            cycles_remaining <= cycles_remaining - counter_t'(1);
        end
    end
endmodule
