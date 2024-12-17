module cache 
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);

    //arrays
    logic         valid_din[4];
    logic [23:0]  tag_din[4];
    logic [255:0] data_din[4];

    logic         valid_dout[4];
    logic [23:0]  tag_dout[4];
    logic [255:0] data_dout[4];

    //logic csb_in[4];
    logic csb_in;
    logic web_in[4];
    logic [3:0] addr_in;
    logic [31:0] data_wmask_in[4];

    //lru signals
    logic [1:0] replace_way;
    logic [2:0] update_lru;
    logic [2:0] curr_lru;
    logic       write_lru;

    //pipeline registers
    cpu_signals_t cpu_signals, cpu_signals_next;

    logic dfp_flag_reg, dfp_flag_reg_next;
    
    logic [255:0] cache_dout;
    logic valid_hit;
    logic [1:0] valid_hit_way;

    logic write_flag;
    logic dirty_flag;
    logic stall_write, stall_write_next;
    // logic write_stall;
    // logic write_stall_done;

    cache_signals_mux_t cache_signals_mux;

    //logic dirty_flag;
    // // logic dfp_wreg, dfp_wreg_next;

    //logic dirty_write_flag, dirty_write_flag_next;
    
    //control signals and flags
    logic init_req;     //check if very first cache request

   logic dirty_off_reg, dirty_off_reg_next;
   logic dirty_replace_flag, dirty_replace_flag_next;
    //assign next state of pipeline registers
    always_comb begin
        cpu_signals_next.cpu_addr    = ufp_addr;
        cpu_signals_next.cpu_rmask   = ufp_rmask;
        cpu_signals_next.cpu_wmask   = ufp_wmask;
        cpu_signals_next.cpu_wdata   = ufp_wdata;
        cpu_signals_next.cpu_addr_tag   = ufp_addr[31:9];
        cpu_signals_next.cpu_addr_set   = ufp_addr[8:5];
        cpu_signals_next.cpu_addr_block = ufp_addr[4:2];
        // cpu_signals_next.cpu_web = 1'b1;
        // cpu_signals_next.cpu_csb = 1'b0;
    end

    //determine is making init request
    always_comb begin
        if(rst) begin
            init_req = 1'b0;
        end
        else begin
            init_req = (cpu_signals.cpu_rmask == 4'b0000 & cpu_signals.cpu_wmask == 4'b0000);
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            cpu_signals <= '0;
        end

        else if(((!valid_hit && init_req) || (valid_hit))) begin
            cpu_signals <= cpu_signals_next;
        end

        else begin
            cpu_signals <= cpu_signals;
        end
    end


    always_ff @ (posedge clk) begin
        if(rst) begin
            stall_write <= 1'b0;
        end
        else begin
            stall_write <= stall_write_next;
        end
    end

    always_comb begin
        stall_write_next = 1'b0;

        if(write_flag == 1'b1) begin
            stall_write_next = 1'b1;
        end
        
        else if(stall_write) begin
            stall_write_next = 1'b0;
        end
    end 

    always_comb begin

        csb_in = 1'b0;
        // if(dfp_read && cache_signals_mux == update_cache_cpu) begin
        //     csb_in = 1'b1;
        // end
        web_in[0] = 1'b1; 
        web_in[1] = 1'b1; 
        web_in[2] = 1'b1; 
        web_in[3] = 1'b1;

        // data_wmask_in[0] = '0;
        // data_wmask_in[1] = '0;
        // data_wmask_in[2] = '0;
        // data_wmask_in[3] = '0;

        // write_flag = 1'b0;
        // if(valid_hit && cpu_signals.cpu_wmask != 4'b0000 && cpu_signals.cpu_rmask == 4'b0000) begin
        //     write_flag = 1'b1;
        // end

        unique case (cache_signals_mux)
            update_cache_cpu : begin
                csb_in = 1'b0;
                if(dfp_read == 1'b1 || dfp_write) begin
                    csb_in = 1'b1;
                end

                web_in = '{default : 1'b1};

                addr_in = ufp_addr[8:5];
                if(stall_write) begin
                    addr_in = cpu_signals.cpu_addr_set;
                end
                // data_wmask_in = '{default : '0};

                if(write_flag) begin
                    addr_in = cpu_signals.cpu_addr_set;
                    web_in[valid_hit_way] = 1'b0;
                end

            end

            update_cache_mem : begin
                if(dfp_resp == 1'b1) begin
                    web_in[replace_way] = 1'b0;
                end
                else begin
                    web_in[replace_way] = 1'b1;
                end

                csb_in = 1'b0;
                addr_in = cpu_signals.cpu_addr_set;
                // data_wmask_in[replace_way] = '1;
            end
            
            default : ;
        endcase
    end
    
    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (csb_in),
            .web0       (web_in[i]),
            .wmask0     (data_wmask_in[i]),
            .addr0      (addr_in),
            .din0       (data_din[i]),
            .dout0      (data_dout[i])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (csb_in),
            .web0       (web_in[i]),
            .addr0      (addr_in),
            .din0       (tag_din[i]),
            .dout0      (tag_dout[i])
        );
        valid_array valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (csb_in),
            .web0       (web_in[i]),
            .addr0      (addr_in),
            .din0       (valid_din[i]),
            .dout0      (valid_dout[i])
        );
    end endgenerate

    //checking if got a hit or not in current cache
    logic read_write_flag;
    logic set_full_flag;
    always_comb begin
        read_write_flag = (cpu_signals.cpu_rmask != 4'b0000 | cpu_signals.cpu_wmask != 4'b0000);

        valid_hit = 1'b0;
        // dirty_miss_flag = 1'b0;
        // if(stall_write) begin
        //     valid_hit = 1'b0;
        // end

        // if(valid_hit == 1'b0 && valid_dout == 4'hf && read_write_flag && !stall_write) begin
        //     dirty_miss_flag = 1'b1;
        // end

        valid_hit_way = 2'b00;
        cache_dout = '0;
        if(cpu_signals.cpu_addr[31:9] == tag_dout[0][22:0] && valid_dout[0] && read_write_flag && !stall_write) begin
            cache_dout = data_dout[0];
            valid_hit = 1'b1;
            valid_hit_way = 2'b00;
        end
        else if(cpu_signals.cpu_addr[31:9] == tag_dout[1][22:0] && valid_dout[1] && read_write_flag && !stall_write) begin
            cache_dout = data_dout[1];
            valid_hit = 1'b1;
            valid_hit_way = 2'b01;
        end
        else if(cpu_signals.cpu_addr[31:9] == tag_dout[2][22:0] && valid_dout[2] && read_write_flag && !stall_write) begin
            cache_dout = data_dout[2];
            valid_hit = 1'b1;
            valid_hit_way = 2'b10;
        end
        else if(cpu_signals.cpu_addr[31:9] == tag_dout[3][22:0] && valid_dout[3] && read_write_flag && !stall_write) begin
            cache_dout = data_dout[3];
            valid_hit = 1'b1;
            valid_hit_way = 2'b11;
        end
        else begin
            valid_hit = 1'b0;
            valid_hit_way = 2'b00;
            cache_dout = '0;
        end

        //CHECK FOR WRITE REQUEST
        write_flag = 1'b0;
        
        if(valid_hit && cpu_signals.cpu_wmask != 4'b0000 && cpu_signals.cpu_rmask == 4'b0000) begin
            write_flag = 1'b1;
        end

        set_full_flag = 1'b0;
        if(valid_dout[0] == 1'b1 && valid_dout[1] == 1'b1 && valid_dout[2] == 1'b1 && valid_dout[3] == 1'b1) begin
            set_full_flag = 1'b1;
        end

        dirty_flag = 1'b0;

        if(set_full_flag && !valid_hit && tag_dout[replace_way][23] == 1'b1 && read_write_flag && !dirty_off_reg && !dirty_replace_flag && !dfp_flag_reg && !stall_write) begin
            dirty_flag = 1'b1;
        end

    end

    logic ufp_flag_reg, ufp_flag_reg_next;

    always_ff @ (posedge clk) begin
        if(rst) begin
            ufp_flag_reg <= 1'b0;
        end
        else begin
            ufp_flag_reg <= ufp_flag_reg_next;
        end
    end


    always_comb begin
        // ufp_rdata = '0;
        ufp_flag_reg_next = 1'b0;
        
        ufp_resp = 1'b0;
        
        if(ufp_flag_reg && !valid_hit) begin
            ufp_resp = 1'b0;
            ufp_flag_reg_next = 1'b0;
        end
        else if(valid_hit && !stall_write) begin
            ufp_resp = 1'b1;
            ufp_flag_reg_next = 1'b1;
        end
        else begin
            ufp_resp = 1'b0;
        end

        ufp_rdata = 'x;
        
        if(ufp_resp && !write_flag) begin 
            unique case(cpu_signals.cpu_addr_block)
            3'b000: ufp_rdata = cache_dout[31:0];
            3'b001: ufp_rdata = cache_dout[63:32];
            3'b010: ufp_rdata = cache_dout[95:64];
            3'b011: ufp_rdata = cache_dout[127:96];
            3'b100: ufp_rdata = cache_dout[159:128];
            3'b101: ufp_rdata = cache_dout[191:160];
            3'b110: ufp_rdata = cache_dout[223:192];
            3'b111: ufp_rdata = cache_dout[255:224];
            default: ufp_rdata = 'x;
            endcase
        end
    end

    always_comb begin   

        cache_signals_mux = update_cache_cpu;
        
        dfp_wdata = 'x;
        
        data_din[0] = '0;
        data_din[1] = '0;
        data_din[2] = '0;
        data_din[3] = '0;

        tag_din[0] = '0;
        tag_din[1] = '0;
        tag_din[2] = '0;
        tag_din[3] = '0;

        valid_din[0] = '0;
        valid_din[1] = '0;
        valid_din[2] = '0;
        valid_din[3] = '0;

        data_wmask_in[0] = '0;
        data_wmask_in[1] = '0;
        data_wmask_in[2] = '0;
        data_wmask_in[3] = '0;

        if(dirty_flag) begin
            dfp_wdata = data_dout[replace_way];
        end

        if(cpu_signals.cpu_rmask == 4'b0000 && cpu_signals.cpu_wmask == 4'b0000) begin
            dfp_addr = '0;
        end

        else if (read_write_flag && dfp_read) begin
            dfp_addr = {cpu_signals.cpu_addr[31:5],{5{1'b0}}};
        end
        else if(read_write_flag && dfp_write) begin
            dfp_addr = {tag_dout[replace_way][22:0],cpu_signals.cpu_addr_set,{5{1'b0}}};
        end
        else begin
            dfp_addr = '0;
        end


        if((dfp_resp || dfp_flag_reg) && !(dirty_flag || dirty_off_reg)) begin
            cache_signals_mux = update_cache_mem;
        end
        
        if(dfp_resp && cache_signals_mux == update_cache_mem) begin
            data_din[replace_way] = dfp_rdata;
            tag_din[replace_way] = {1'b0,cpu_signals.cpu_addr[31:9]};
            valid_din[replace_way] = 1'b1;
        end

        unique case(cache_signals_mux)
            update_cache_cpu : begin
                if(!write_flag) begin
                    data_wmask_in = '{default : '0};
                end
            end

            update_cache_mem : data_wmask_in[replace_way] = '1;
        endcase

        //if writing assign dirty bit and data values in
        if(write_flag && cache_signals_mux == update_cache_cpu) begin
            tag_din[valid_hit_way][23] = 1'b1;
            tag_din[valid_hit_way][22:0] = cpu_signals.cpu_addr_tag;
            valid_din[valid_hit_way] = 1'b1;
            unique case(cpu_signals.cpu_addr_block)
                3'b000 : begin
                    data_wmask_in[valid_hit_way][3:0] = cpu_signals.cpu_wmask;
                    data_din[valid_hit_way][31:0] = cpu_signals.cpu_wdata;
                end
                3'b001: begin
                    data_wmask_in[valid_hit_way][7:4] = cpu_signals.cpu_wmask;
                    data_din[valid_hit_way][63:32] = cpu_signals.cpu_wdata;
                end
                3'b010: begin
                    data_wmask_in[valid_hit_way][11:8] = cpu_signals.cpu_wmask;
                    data_din[valid_hit_way][95:64] = cpu_signals.cpu_wdata;
                end
                3'b011: begin
                    data_wmask_in[valid_hit_way][15:12] = cpu_signals.cpu_wmask;
                    data_din[valid_hit_way][127:96] = cpu_signals.cpu_wdata;
                end
                3'b100: begin
                    data_wmask_in[valid_hit_way][19:16] = cpu_signals.cpu_wmask;
                    data_din[valid_hit_way][159:128] = cpu_signals.cpu_wdata;
                end
                3'b101: begin
                    data_wmask_in[valid_hit_way][23:20] = cpu_signals.cpu_wmask;
                    data_din[valid_hit_way][191:160] = cpu_signals.cpu_wdata;
                end
                3'b110: begin
                    data_wmask_in[valid_hit_way][27:24] = cpu_signals.cpu_wmask;
                    data_din[valid_hit_way][223:192] = cpu_signals.cpu_wdata;
                end
                3'b111: begin
                    data_wmask_in[valid_hit_way][31:28] = cpu_signals.cpu_wmask;
                    data_din[valid_hit_way][255:224] = cpu_signals.cpu_wdata;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            dfp_flag_reg <= 1'b0;
        end
        else begin
            dfp_flag_reg <= dfp_flag_reg_next;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            dirty_off_reg <= '0;
        end
        else begin
            dirty_off_reg <= dirty_off_reg_next;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            dirty_replace_flag <= '0;
        end
        else begin
            dirty_replace_flag <= dirty_replace_flag_next;
        end
    end

    always_comb begin
        
        dfp_read = 1'b0;
        dfp_flag_reg_next = 1'b0;
        dirty_replace_flag_next = '0;

        dfp_write = 1'b0;


        if((dfp_resp && dirty_flag) || (dirty_replace_flag && !dfp_resp)) begin
            dirty_replace_flag_next = 1'b1;
        end
        else if(dfp_resp && !dirty_off_reg) begin
            dirty_replace_flag_next = 1'b0;
        end
        
        if(dirty_flag && !dirty_replace_flag && !dfp_flag_reg && !stall_write) begin
            dfp_write = 1'b1;
        end

        dirty_off_reg_next = 1'b0;
        
        if(dirty_flag && dfp_resp && !dirty_off_reg) begin
            dirty_off_reg_next = 1'b1;
        end
        else if(dirty_off_reg) begin
            dirty_off_reg_next = 1'b0;
        end

        // if(dirty_flag) begin
        //     dfp_write = 1'b1;
        // end

        if(dfp_resp) begin
            dfp_flag_reg_next = 1'b1;
        end
        else begin
            dfp_flag_reg_next = 1'b0;
        end
        
        if(dfp_flag_reg && !dirty_replace_flag) begin
            dfp_read = 1'b0;
            // dfp_write = 1'b0;
        end
        else if((!valid_hit && read_write_flag && !stall_write) && (!dirty_flag || dirty_replace_flag)) begin
            dfp_read = 1'b1;
        end
        else begin
            dfp_read = 1'b0;
        end
    end

    //LRU ENCODING LOGIC
    //N0: 0,1 (N1) <---(0) (1) ---> (N2) 2,3
    //N1: 0 <---(0) (1) ---> 1
    //N2: 2 <---(0) (1) ---> 3

    always_comb begin
        update_lru = curr_lru;
        write_lru = 1'b1;

        if(ufp_resp) begin
            write_lru = 1'b0;
            unique case(valid_hit_way)
                2'b00: update_lru = {curr_lru[2],valid_hit_way[0],valid_hit_way[1]};
                2'b01: update_lru = {curr_lru[2],valid_hit_way[0],valid_hit_way[1]};
                2'b10: update_lru = {valid_hit_way[0],curr_lru[1],valid_hit_way[1]};
                2'b11: update_lru = {valid_hit_way[0],curr_lru[1],valid_hit_way[1]};
                default : update_lru = curr_lru;
            endcase
        end

        //CURR LRU REPRESENTS MOST RECENTLY ACCESSED, SO REPLACE OPPOSITE
        unique case(curr_lru)
            3'b000 : replace_way = 2'b11;
            3'b001 : replace_way = 2'b01;
            3'b010 : replace_way = 2'b11;
            3'b011 : replace_way = 2'b00;
            3'b100 : replace_way = 2'b10;
            3'b110 : replace_way = 2'b10;
            3'b101 : replace_way = 2'b01;
            3'b111 : replace_way = 2'b00;
            default : replace_way = valid_hit_way;
        endcase
    end

    logic [2:0] write_port_out;

    // logic lru_read;

    // always_comb begin
    //     lru_read = 1'b1;
    //     if(read_write_flag) begin
    //         lru_read = 1'b0;
    //     end
    // end
    logic [3:0] lru_addr;
    logic lru_write;

    always_comb begin
        lru_write = 1'b1;
        if(valid_hit) begin
            lru_write = 1'b0;
        end
        else begin
            lru_write = 1'b1;
        end
    end
    always_comb begin
        lru_addr = '0;
        if(read_write_flag) begin
            lru_addr = cpu_signals.cpu_addr_set;
        end
    end


    lru_array lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (csb_in),
        .web0       (1'b1),                     //read only port
        .addr0      (addr_in),            //read for current set
        .din0       (3'b000),                     //doesn't matter because read only
        .dout0      (curr_lru),
        .csb1       (lru_write),
        .web1       (lru_write),
        .addr1      (lru_addr),
        .din1       (update_lru),                 //new PLRU value for the current set
        .dout1      (write_port_out)              //write only port (so throw away value)
    );


endmodule