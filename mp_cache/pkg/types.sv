package rv32i_types;

    typedef struct packed {
        logic [31:0] cpu_addr;
        logic [3:0]  cpu_rmask;
        logic [3:0]  cpu_wmask;
        logic [31:0] cpu_wdata;

        logic [22:0] cpu_addr_tag;
        logic [3:0]  cpu_addr_set;
        logic [2:0]  cpu_addr_block;
    } cpu_signals_t;

    typedef enum logic { 
        cpu_to_cache = 1'b0,
        mem_to_cache = 1'b1
    } mask_mux_t;

    typedef enum logic { 
        cpu_to_cache_offset = 1'b0,
        mem_to_cache_block = 1'b1
    } wdata_mux_t;

    typedef enum logic { 
        update_cache_cpu = 1'b0,
        update_cache_mem = 1'b1
    } cache_signals_mux_t;

endpackage
