module cpu
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    output  logic   [31:0]  imem_addr,
    output  logic   [3:0]   imem_rmask,
    input   logic   [31:0]  imem_rdata,
    input   logic           imem_resp,

    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    input   logic   [31:0]  dmem_rdata,
    output  logic   [31:0]  dmem_wdata,
    input   logic           dmem_resp
);
            
            logic   [31:0]  pc;
            logic   [31:0]  pc_next;
            logic   [63:0]  order;
            logic   [63:0]  order_next;


            logic           commit;

            logic           regf_we;
            logic           regf_we_wb;

            logic   [31:0]  rd_v;
            logic   [4:0]   rs1_s;
            logic   [4:0]   rs2_s;
            logic   [4:0]   rd_s;
            logic   [4:0]   rd_s_wb;
            logic   [31:0]  rs1_v;
            logic   [31:0]  rs2_v;

            logic   [31:0]  inst_in;

            logic   decode_data_hazard_rs1;
            logic   decode_data_hazard_rs2;

            logic forward_mem_rs1;
            logic forward_mem_rs2;

            logic forward_ex_rs1;
            logic forward_ex_rs2;

            logic br_en;

            logic mem_wb_commit;

            logic   [31:0]  aluout;

            logic stall_pipeline_dmem;
            logic stall_pipeline_flag;

            logic load_hazard_bubble_rs1;
            logic load_hazard_bubble_rs2;

            logic flush_for_jump;
            logic flush_for_branch;

            pc_sel_t pc_sel_mux;

            //create pipeline registers
            if_id_stage_reg_t if_id_reg, if_id_reg_next;
            id_ex_stage_reg_t id_ex_reg, id_ex_reg_next;
            ex_mem_stage_reg_t ex_mem_reg, ex_mem_reg_next;
            mem_wb_stage_reg_t mem_wb_reg, mem_wb_reg_next;

            inst_breakdown_t decode_inst;
            control_word_t decode_control;

            // save_on_control_t branch_reg, branch_reg_next;

            logic [31:0] exec_jump_out;


    //assigning all forwarding signals to avoid data hazards
    always_comb begin
        if((mem_wb_reg.control.regf_we && (mem_wb_reg.inst_info.rd_s == if_id_reg.inst_info.inst[19:15]) &&
        !(ex_mem_reg.control.regf_we && (ex_mem_reg.inst_info.rd_s == if_id_reg.inst_info.inst[19:15])) &&
        !(id_ex_reg.control.regf_we && (id_ex_reg.inst_info.rd_s == if_id_reg.inst_info.inst[19:15])))) begin
            decode_data_hazard_rs1 = 1'b1;
        end
        else begin
            decode_data_hazard_rs1 = 1'b0;
        end

        if((mem_wb_reg.control.regf_we && (mem_wb_reg.inst_info.rd_s == if_id_reg.inst_info.inst[24:20]) &&
        !(ex_mem_reg.control.regf_we && (ex_mem_reg.inst_info.rd_s == if_id_reg.inst_info.inst[24:20])) &&
        !(id_ex_reg.control.regf_we && (id_ex_reg.inst_info.rd_s == if_id_reg.inst_info.inst[24:20])))) begin
            decode_data_hazard_rs2 = 1'b1;
        end
        else begin
            decode_data_hazard_rs2 = 1'b0;
        end
    end

    always_comb begin
        if((mem_wb_reg.control.regf_we && (mem_wb_reg.inst_info.rd_s != 5'b00000) && 
        (mem_wb_reg.inst_info.rd_s == id_ex_reg.inst_info.rs1_s)) &&
        !(ex_mem_reg.control.regf_we && (ex_mem_reg.inst_info.rd_s == id_ex_reg.inst_info.rs1_s))) begin
            forward_mem_rs1 = 1'b1;
        end
        else begin
            forward_mem_rs1 = 1'b0;
        end

        if((mem_wb_reg.control.regf_we && (mem_wb_reg.inst_info.rd_s != 5'b00000) && 
        (mem_wb_reg.inst_info.rd_s == id_ex_reg.inst_info.rs2_s)) &&
        !(ex_mem_reg.control.regf_we && (ex_mem_reg.inst_info.rd_s == id_ex_reg.inst_info.rs2_s))) begin
            forward_mem_rs2 = 1'b1;
        end
        else begin
            forward_mem_rs2 = 1'b0;
        end
    end

    always_comb begin
        if(ex_mem_reg.control.regf_we && (ex_mem_reg.inst_info.rd_s != 5'b00000) && 
        ex_mem_reg.inst_info.rd_s == id_ex_reg.inst_info.rs1_s) begin
            forward_ex_rs1 = 1'b1;
            if(ex_mem_reg.inst_info.opcode == op_b_load) begin
                load_hazard_bubble_rs1 = 1'b1;
            end
            else begin
                load_hazard_bubble_rs1 = 1'b0;
            end
        end
        else begin
            forward_ex_rs1 = 1'b0;
            load_hazard_bubble_rs1 = 1'b0;
        end

        if(ex_mem_reg.control.regf_we && (ex_mem_reg.inst_info.rd_s != 5'b00000) && 
        ex_mem_reg.inst_info.rd_s == id_ex_reg.inst_info.rs2_s) begin
            forward_ex_rs2 = 1'b1;
            if(ex_mem_reg.inst_info.opcode == op_b_load) begin
                load_hazard_bubble_rs2 = 1'b1;
            end
            else begin
                load_hazard_bubble_rs2 = 1'b0;
            end
        end
        else begin
            forward_ex_rs2 = 1'b0;
            load_hazard_bubble_rs2 = 1'b0;
        end
    end


    // assign forward_ex_rs1 = (ex_mem_reg.control.regf_we && (ex_mem_reg.inst_info.rd_s != 5'b00000) && ex_mem_reg.inst_info.rd_s == id_ex_reg.inst_info.rs1_s) ? 1'b1 : 1'b0;
    // assign forward_ex_rs2 = (ex_mem_reg.control.regf_we && (ex_mem_reg.inst_info.rd_s != 5'b00000) && ex_mem_reg.inst_info.rd_s == id_ex_reg.inst_info.rs2_s) ? 1'b1 : 1'b0;

    // assign forward_mem_rs1 = (mem_wb_reg.control.regf_we && (mem_wb_reg.inst_info.rd_s != 5'b00000) && !forward_ex_rs1 && mem_wb_reg.inst_info.rd_s == id_ex_reg.inst_info.rs1_s) ? 1'b1 : 1'b0;
    // assign forward_mem_rs2 = (mem_wb_reg.control.regf_we && (mem_wb_reg.inst_info.rd_s != 5'b00000) && !forward_ex_rs2 && mem_wb_reg.inst_info.rd_s == id_ex_reg.inst_info.rs2_s) ? 1'b1 : 1'b0;

    // assign decode_data_hazard_rs1 = (mem_wb_reg.inst_info.rd_s == if_id_reg.inst_info.inst[19:15] && !forward_ex_rs1 && !forward_mem_rs1) ? 1'b1 : 1'b0;
    // assign decode_data_hazard_rs2 = (mem_wb_reg.inst_info.rd_s == if_id_reg.inst_info.inst[24:20] && !forward_ex_rs2 && !forward_mem_rs2) ? 1'b1 : 1'b0;   
    
    // assign load_hazard_bubble_rs1 = (ex_mem_reg.control.regf_we && (mem_wb_reg.inst_info.rd_s != 5'b00000) && !forward_ex_rs1 && !forward_mem_rs1 && ex_mem_reg.inst_info.rd_s == id_ex_reg.inst_info.rs1_s) ? 1'b1 : 1'b0;
    // assign load_hazard_bubble_rs2 = (ex_mem_reg.control.regf_we && (mem_wb_reg.inst_info.rd_s != 5'b00000) && !forward_ex_rs2 && !forward_mem_rs2 && ex_mem_reg.inst_info.rd_s == id_ex_reg.inst_info.rs2_s) ? 1'b1 : 1'b0;
    
    logic stall_on_load;

    // always_comb begin
    //     if((flush_for_branch || flush_for_jump) && ~imem_resp) begin
    //         //save order_next
    //         //save pc_next

    //         //restore pc and order when imem_resp comes back high
            
    //         jump_reg_next.new_pc = exec_jump_out;
    //         jump_reg_next.new_order = id_ex_reg.rvfi_signals.monitor_order;
    //     end
    //     else begin
    //         jump_reg_next = 1'b0;
    //     end
    // end

    // always_ff @(posedge clk) begin
    //     if(flush_for_branch || flush_for_jump || imem_resp) begin
    //         jump_reg <= jump_reg_next;
    //     end
    //     else begin
    //         jump_reg <= jump_reg;
    //     end
    // end

    always_ff @(posedge clk) begin
        pc <= pc_next;
        order <= order_next;
    end

    assign stall_on_load = (load_hazard_bubble_rs1 || load_hazard_bubble_rs2);

    //this will be changed to mux
    // assign order_next = (rst) ? '0 : ((mem_wb_reg.rvfi_signals.monitor_valid & ~stall_pipeline_flag) ? order + 'd1 : order);

    always_comb begin
        if(rst) begin
            order_next = '0;
        end
        else begin
            if(~stall_pipeline_flag & ~stall_on_load & (flush_for_branch || flush_for_jump)) begin
                order_next = id_ex_reg.rvfi_signals.monitor_order + 'd1;
                //order_next = order - 'd1;
            end
            else if(imem_resp & ~stall_pipeline_flag && ~stall_on_load) begin
                order_next = order + 'd1;
            end
            else begin
                order_next = order;
            end
        end
    end

    always_comb begin
        if(rst) begin
            pc_next = 32'h1eceb000;
        end
        else begin
            if (imem_resp & ~stall_pipeline_flag & ~stall_on_load & pc_sel_mux == pc_next_out) begin
                pc_next = pc + 'd4;
            end
            else if(pc_sel_mux == jump_out) begin
                // pc_next = exec_jump_out - 'd4;
                pc_next = exec_jump_out;
            end
            else begin
                pc_next = pc;
            end
        end
    end

    // always_comb begin
    //     if(rst) begin
    //         order_next = '0;
    //     end
    //     else begin
    //         // if((mem_wb_reg.rvfi_signals.monitor_valid & ~stall_pipeline_flag)) begin
    //         //     order_next = order + 'd1;
    //         // end
    //         // // else if (flush_for_branch || flush_for_jump) begin
    //         // //     order_next = order - 1;
    //         // // end
    //         // else begin
    //         //     order_next = order;
    //         // end
    //         if(imem_resp & ~stall_pipeline_flag) begin
    //             order_next = order + 'd1;
    //             if(flush_for_branch || flush_for_jump) begin
    //                 order_next = order - 'd1;
    //             end
    //             else begin
    //                 order_next = order + 'd1;
    //             end
    //         end
    //         else begin
    //             if((flush_for_branch || flush_for_jump) && ~stall_on_load) begin
    //                 order_next = order - 'd1;
    //             end
    //             else begin
    //                 order_next = order;
    //             end
    //         end
    //     end
    // end
    //assign pc_next = (rst) ? 32'h1eceb000 : ((imem_resp & ~stall_pipeline_flag & ~stall_on_load) ? pc + 'd4 : pc);
    //assign order_next = (rst) ? '0 : ((mem_wb_reg.rvfi_signals.monitor_valid & ~stall_pipeline_flag) ? order + 'd1 : order);
    assign commit = (rst) ? 1'b0 : ((imem_resp & ~stall_pipeline_flag & ~stall_on_load) ? 1'b1 : 1'b0);
    assign inst_in = (imem_resp & ~stall_pipeline_flag &  ~stall_on_load) ? imem_rdata : '0;
    assign imem_addr = pc_next;
    assign imem_rmask = 4'b1111;

    always_ff @(posedge clk) begin
        if (rst) begin
            if_id_reg <= '0;
            id_ex_reg <= '0;
            ex_mem_reg <= '0;
            mem_wb_reg <= '0;
        end
        else begin
            if(stall_pipeline_flag) begin
                if_id_reg <= if_id_reg;
                id_ex_reg <= id_ex_reg;
                ex_mem_reg <= ex_mem_reg;
                mem_wb_reg <= mem_wb_reg;
            end
            else begin
                if(stall_on_load) begin
                    if_id_reg <= if_id_reg;
                    id_ex_reg <= id_ex_reg;
                    ex_mem_reg <= '0;
                    mem_wb_reg <= mem_wb_reg_next;
                end
                else if (flush_for_jump || flush_for_branch /*|| jump_reg*/) begin
                    // if(jump_reg) begin
                    //     if_id_reg <= '0;
                    // if(jump_reg) begin
                    //     if_id_reg <= '0;
                    // end
                    //else begin
                        if_id_reg <= '0;
                        id_ex_reg <= '0;
                        ex_mem_reg <= ex_mem_reg_next;
                        mem_wb_reg <= mem_wb_reg_next;
                    end
                // end
                else begin
                    if_id_reg <= if_id_reg_next;
                    id_ex_reg <= id_ex_reg_next;
                    ex_mem_reg <= ex_mem_reg_next;
                    mem_wb_reg <= mem_wb_reg_next;
                end
            end
        end
   end
    
    always_comb begin
        if_id_reg_next.control = '0;
        if_id_reg_next.inst_info = '0;
        if_id_reg_next.pc = pc;
        if_id_reg_next.pc_next = pc_next;
        if_id_reg_next.inst_info.inst = inst_in;
    end

    always_comb begin
        if_id_reg_next.rvfi_signals = '0;
        if_id_reg_next.rvfi_signals.monitor_pc_rdata  =  pc;
        if_id_reg_next.rvfi_signals.monitor_pc_wdata  =  pc_next;
        if_id_reg_next.rvfi_signals.monitor_valid     =  (flush_for_jump || flush_for_branch) ? 1'b0 : commit; 
        if_id_reg_next.rvfi_signals.monitor_order     =  order;
        if_id_reg_next.rvfi_signals.monitor_inst      =  inst_in;
    end


    decode get_decode(
        .inst_in(if_id_reg.inst_info.inst),
        // .pc_in(if_id_reg.pc),
        .rs1_sout(rs1_s),
        .rs2_sout(rs2_s),
        //.rs1_in(rs1_v),
        .rd_sout(rd_s),
        .regf_we_out(regf_we),
        .inst_sig_out(decode_inst),
        .control_sig_out(decode_control)
    );

    //carry over all fetch stage info
    assign id_ex_reg_next.pc = if_id_reg.pc;
    assign id_ex_reg_next.pc_next = if_id_reg.pc_next;

    //all decode stage rvfi signals
    always_comb begin
        id_ex_reg_next.rvfi_signals = if_id_reg.rvfi_signals;
        //id_ex_reg_next.rvfi_signals.monitor_valid   =  (flush_for_jump) ? 1'b0 : commit; 
        id_ex_reg_next.rvfi_signals.monitor_rs1_addr = rs1_s;
        id_ex_reg_next.rvfi_signals.monitor_rs2_addr = rs2_s;
        id_ex_reg_next.rvfi_signals.monitor_rd_addr = rd_s;
        id_ex_reg_next.rvfi_signals.monitor_regf_we = regf_we;
    end

    //assign all decode insts and control
    always_comb begin
        id_ex_reg_next.control = decode_control;
        id_ex_reg_next.inst_info = decode_inst;
        id_ex_reg_next.inst_info.inst = if_id_reg.inst_info.inst;
        id_ex_reg_next.inst_info.rs1_v = rs1_v;
        id_ex_reg_next.inst_info.rs2_v = rs2_v;
    end

        logic   [3:0] rmask_decode;
        logic   [3:0] wmask_decode;
        logic   [31:0] addr_decode;
        logic   [31:0] wdata_decode;
        logic   [31:0]  rvfi_from_ex_rs1;
        logic   [31:0]  rvfi_from_ex_rs2;

    execute get_execute(
        .control_signals(id_ex_reg.control),
        .inst_info(id_ex_reg.inst_info),
        .forward_from_mem(mem_wb_reg.rd_v),
        .forward_from_ex(ex_mem_reg.rd_v),
        .forward_ex_rs1_flag(forward_ex_rs1),
        .forward_ex_rs2_flag(forward_ex_rs2),
        .forward_mem_rs1_flag(forward_mem_rs1),
        .forward_mem_rs2_flag(forward_mem_rs2),
        .pc_in(id_ex_reg.pc),
        .i_imm_in(id_ex_reg.inst_info.i_imm),
        .aluout_out(aluout),
        .mem_wdata(wdata_decode),
        .mem_addr_out(addr_decode),
        .mem_wmask_out(wmask_decode),
        .mem_rmask_out(rmask_decode),
        .stall_pipeline_out(stall_pipeline_dmem),
        .rvfi_ex_rs1_out(rvfi_from_ex_rs1),
        .rvfi_ex_rs2_out(rvfi_from_ex_rs2),
        .pc_sel_mux_out(pc_sel_mux),
        .set_jump_flush(flush_for_jump),
        .set_branch_flush(flush_for_branch),
        .jump_addr_out(exec_jump_out)
    );
    
    assign dmem_wdata = wdata_decode;
    
    //assigning AlU output in execute stage rvfi_signals
    always_comb begin
        ex_mem_reg_next.rvfi_signals = id_ex_reg.rvfi_signals;
        ex_mem_reg_next.rvfi_signals.monitor_rs1_rdata = rvfi_from_ex_rs1;
        ex_mem_reg_next.rvfi_signals.monitor_rs2_rdata = rvfi_from_ex_rs2;
        ex_mem_reg_next.rvfi_signals.monitor_rd_wdata = aluout;

        if(flush_for_jump) begin
            ex_mem_reg_next.rvfi_signals.monitor_pc_wdata = exec_jump_out;
            ex_mem_reg_next.rvfi_signals.monitor_rd_wdata = id_ex_reg.pc + 'd4;
        end
        
        if(flush_for_branch) begin
            ex_mem_reg_next.rvfi_signals.monitor_pc_wdata = exec_jump_out;
        end

        // if((flush_for_branch || flush_for_jump) && ~imem_resp) begin
        //     branch_reg_next.br_en = 1'b1;
        //     branch_reg_next.new_pc = exec_jump_out;
        //     branch_reg_next.new_order = id_ex_reg.rvfi_signals.monitor_order;
        // end

        if(id_ex_reg.inst_info.opcode == op_b_br) begin
            ex_mem_reg_next.rvfi_signals.monitor_rd_addr = '0;
            ex_mem_reg_next.rvfi_signals.monitor_rd_wdata = '0;
        end

        else begin
            ex_mem_reg_next.rvfi_signals.monitor_rd_addr = (wmask_decode > 4'b0000) ? '0 : id_ex_reg.rvfi_signals.monitor_rd_addr;
        end 

        ex_mem_reg_next.rvfi_signals.monitor_mem_addr  = addr_decode;
        ex_mem_reg_next.rvfi_signals.monitor_mem_rmask = rmask_decode;
        ex_mem_reg_next.rvfi_signals.monitor_mem_wmask = wmask_decode;
        ex_mem_reg_next.rvfi_signals.monitor_mem_wdata = wdata_decode;
        // ex_mem_reg_next.rvfi_signals.monitor_rd_addr = (wmask_decode > 4'b0000) ? '0 : id_ex_reg.rvfi_signals.monitor_rd_addr; 
    end

    assign ex_mem_reg_next.pc = id_ex_reg.pc;
    assign ex_mem_reg_next.pc_next = id_ex_reg.pc_next;

    always_comb begin
        ex_mem_reg_next.control = id_ex_reg.control;
        ex_mem_reg_next.control.br_en = flush_for_jump;
    end

    assign ex_mem_reg_next.inst_info = id_ex_reg.inst_info;

    assign ex_mem_reg_next.rs1_v = rvfi_from_ex_rs1;
    assign ex_mem_reg_next.rs2_v = rvfi_from_ex_rs2;

    always_comb begin
        if(flush_for_jump) begin
            ex_mem_reg_next.rd_v =  id_ex_reg.pc + 'd4;
        end
        else begin
            ex_mem_reg_next.rd_v = aluout;
        end
    end
    assign ex_mem_reg_next.rmask_decode = rmask_decode;
    assign ex_mem_reg_next.wmask_decode = wmask_decode;
    assign ex_mem_reg_next.addr_decode = addr_decode;
    assign ex_mem_reg_next.stall_pipeline = stall_pipeline_dmem;


    //MAKE CALL TO DMEM AT THE END OF DECODE STAGE
    //uses main module outputs
    
    always_comb begin
        dmem_addr  = {addr_decode[31:2],2'b0};
        dmem_rmask = rmask_decode;
        dmem_wmask = wmask_decode;
    end

    logic [31:0] rdv_out;

    //DO MEMORY STAGE HERE
    always_comb begin
        mem_wb_reg_next.control = ex_mem_reg.control;
        mem_wb_reg_next.control.regf_we = ex_mem_reg.control.regf_we;
        rdv_out = ex_mem_reg.rd_v;
        stall_pipeline_flag = ex_mem_reg.stall_pipeline;
        unique case(ex_mem_reg.inst_info.opcode)
        op_b_load : begin
            if(dmem_resp & ex_mem_reg.stall_pipeline) begin
                mem_wb_reg_next.control.regf_we = 1'b1;
                stall_pipeline_flag = 1'b0;
                unique case (ex_mem_reg.inst_info.funct3)
                    load_f3_lb : rdv_out = {{24{dmem_rdata[7 +8 *ex_mem_reg.addr_decode[1:0]]}}, dmem_rdata[8 *ex_mem_reg.addr_decode[1:0] +: 8 ]};
                    load_f3_lbu: rdv_out = {{24{1'b0}}, dmem_rdata[8 *ex_mem_reg.addr_decode[1:0] +: 8 ]};
                    load_f3_lh : rdv_out = {{16{dmem_rdata[15+16*ex_mem_reg.addr_decode[1]  ]}}, dmem_rdata[16*ex_mem_reg.addr_decode[1]   +: 16]};
                    load_f3_lhu: rdv_out = {{16{1'b0}}, dmem_rdata[16*ex_mem_reg.addr_decode[1]   +: 16]};
                    load_f3_lw : rdv_out = dmem_rdata;
                    default    : rdv_out = 'x;
                endcase
            end
        end
        op_b_store : begin
            if(dmem_resp & ex_mem_reg.stall_pipeline) begin
                stall_pipeline_flag = 1'b0;
            end
        end
        default : ;
        endcase
    end  

    // assign decode_data_hazard_rs1 = (mem_wb_reg.inst_info.rd_s == rs1_s) ? 1'b1 : 1'b0;
    // assign decode_data_hazard_rs2 = (mem_wb_reg.inst_info.rd_s == rs2_s) ? 1'b1 : 1'b0;     

    regfile regfile(
        .clk(clk),
        .rst(rst),
        .regf_we(regf_we_wb),
        .rd_v(rd_v),
        .rs1_s(rs1_s),
        .rs2_s(rs2_s),
        .rd_s(rd_s_wb),
        .rs1_v(rs1_v),
        .rs2_v(rs2_v),
        .data_hazard_rs1(decode_data_hazard_rs1),
        .data_hazard_rs2(decode_data_hazard_rs2)
    );
    
    //all pc values for mem stage
    assign mem_wb_reg_next.pc = ex_mem_reg.pc;
    assign mem_wb_reg_next.pc_next = ex_mem_reg.pc_next;

    //all inst values for mem stage
    assign mem_wb_reg_next.inst_info = ex_mem_reg.inst_info;


    always_comb begin
        mem_wb_reg_next.rvfi_signals = ex_mem_reg.rvfi_signals;
        mem_wb_reg_next.rd_v = rdv_out;
        mem_wb_reg_next.rvfi_signals.monitor_rd_wdata = rdv_out;
        
        if(ex_mem_reg.inst_info.opcode == op_b_jal || 
        (ex_mem_reg.inst_info.opcode == op_b_jalr && ex_mem_reg.inst_info.funct3 == 3'b000)) begin
            mem_wb_reg_next.rvfi_signals.monitor_rd_wdata = ex_mem_reg.pc + 'd4;
        end

        mem_wb_reg_next.rvfi_signals.monitor_order = ex_mem_reg.rvfi_signals.monitor_order;
        mem_wb_reg_next.rvfi_signals.monitor_mem_rdata = (ex_mem_reg.inst_info.opcode == op_b_load) ? dmem_rdata : '0;
    end

    //all register values for mem stage
    assign mem_wb_reg_next.rs1_v = ex_mem_reg.rs1_v;
    assign mem_wb_reg_next.rs2_v = ex_mem_reg.rs2_v;

    //assign register outputs   WB STAGE
    assign regf_we_wb = mem_wb_reg.control.regf_we;
    assign rd_s_wb = mem_wb_reg.inst_info.rd_s;
    assign rd_v = mem_wb_reg.rd_v;


            logic           monitor_valid;
            logic   [63:0]  monitor_order;
            logic   [31:0]  monitor_inst;
            logic   [4:0]   monitor_rs1_addr;
            logic   [4:0]   monitor_rs2_addr;
            logic   [31:0]  monitor_rs1_rdata;
            logic   [31:0]  monitor_rs2_rdata;
            logic           monitor_regf_we;
            logic   [4:0]   monitor_rd_addr;
            logic   [31:0]  monitor_rd_wdata;
            logic   [31:0]  monitor_pc_rdata;
            logic   [31:0]  monitor_pc_wdata;
            logic   [31:0]  monitor_mem_addr;
            logic   [3:0]   monitor_mem_rmask;
            logic   [3:0]   monitor_mem_wmask;
            logic   [31:0]  monitor_mem_rdata;
            logic   [31:0]  monitor_mem_wdata;


    assign monitor_valid     = mem_wb_reg.rvfi_signals.monitor_valid;
    assign monitor_order     = mem_wb_reg.rvfi_signals.monitor_order;
    assign monitor_inst      = mem_wb_reg.rvfi_signals.monitor_inst;
    assign monitor_rs1_addr  = mem_wb_reg.rvfi_signals.monitor_rs1_addr;
    assign monitor_rs2_addr  = mem_wb_reg.rvfi_signals.monitor_rs2_addr;
    assign monitor_rs1_rdata = mem_wb_reg.rvfi_signals.monitor_rs1_rdata;
    assign monitor_rs2_rdata = mem_wb_reg.rvfi_signals.monitor_rs2_rdata;
    assign monitor_rd_addr   = mem_wb_reg.rvfi_signals.monitor_rd_addr;
    assign monitor_rd_wdata  = mem_wb_reg.rvfi_signals.monitor_rd_wdata;
    assign monitor_pc_rdata  = mem_wb_reg.rvfi_signals.monitor_pc_rdata;
    assign monitor_pc_wdata  = mem_wb_reg.rvfi_signals.monitor_pc_wdata;
    assign monitor_mem_addr  = mem_wb_reg.rvfi_signals.monitor_mem_addr;
    assign monitor_mem_rmask = mem_wb_reg.rvfi_signals.monitor_mem_rmask;
    assign monitor_mem_wmask = mem_wb_reg.rvfi_signals.monitor_mem_wmask;
    assign monitor_mem_rdata = mem_wb_reg.rvfi_signals.monitor_mem_rdata;
    assign monitor_mem_wdata = mem_wb_reg.rvfi_signals.monitor_mem_wdata;

endmodule : cpu