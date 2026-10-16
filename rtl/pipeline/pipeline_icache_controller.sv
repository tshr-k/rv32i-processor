import rv32i_pkg::*;

// Serves instruction fetches from the cache, and refills the cache from memory on a miss
// Memory responses only ever fill the cache, and the fetch is then retried as a lookup
module pipeline_icache_controller (
    input  logic        clk,
    input  logic        reset,

    // Datapath interface
    input  word_t       fetch_addr,  // Byte address
    output word_t       instruction,
    output logic        instruction_valid,  // Deasserted while a miss is being serviced

    // Cache interface
    output logic [31:2] cache_lookup_word_addr,
    input  logic        cache_hit,
    input  word_t       cache_lookup_data,
    output logic        cache_fill_en,
    output logic [31:2] cache_fill_word_addr,
    output word_t       cache_fill_data,

    // Memory interface
    output logic        memory_request_valid,
    input  logic        memory_request_ready,
    output logic [31:2] memory_request_word_addr,
    input  logic        memory_response_valid,
    input  word_t       memory_response_data
);
    typedef enum logic [1:0] {
        ICACHE_IDLE,          // Looking up fetch_addr in the cache
        ICACHE_REQUEST,       // Waiting for the memory to accept the refill request
        ICACHE_WAIT_RESPONSE  // Waiting for the memory to respond with the refill data
    } icache_state_t;

    icache_state_t state;
    logic [31:2]   miss_word_addr;  // If the requested word address missed, it is latched in case fetch_addr changes while filling

    assign cache_lookup_word_addr = fetch_addr[31:2];  // The current fetch address is always looked up in the cache, even if a previous fill is still in progress

    assign instruction       = cache_lookup_data;
    assign instruction_valid = (state == ICACHE_IDLE) && cache_hit;

    assign memory_request_valid     = (state == ICACHE_REQUEST);
    assign memory_request_word_addr = miss_word_addr;

    assign cache_fill_en        = (state == ICACHE_WAIT_RESPONSE) && memory_response_valid;
    assign cache_fill_word_addr = miss_word_addr;
    assign cache_fill_data      = memory_response_data;

    icache_state_t state_next;
    logic [31:2]   miss_word_addr_next;

    // Next state logic
    always_comb begin
        state_next          = state;
        miss_word_addr_next = miss_word_addr;

        unique case (state)
            ICACHE_IDLE: begin
                if (!cache_hit) begin
                    state_next          = ICACHE_REQUEST;
                    miss_word_addr_next = fetch_addr[31:2];
                end
            end
            ICACHE_REQUEST: begin
                if (memory_request_ready)
                    state_next = ICACHE_WAIT_RESPONSE;
            end
            ICACHE_WAIT_RESPONSE: begin
                if (memory_response_valid)
                    state_next = ICACHE_IDLE;  // The retried lookup will now hit, unless fetch_addr has changed
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= ICACHE_IDLE;
        end else begin
            state          <= state_next;
            miss_word_addr <= miss_word_addr_next;
        end
    end
endmodule
