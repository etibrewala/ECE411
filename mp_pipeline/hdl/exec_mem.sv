module execute
import rv32i_types::*;
(
    input control_word_t        control_signals,
    input inst_breakdown_t      inst_info,
    input   logic  [31:0]       pc_in,
    input   logic   [31:0]      i_imm_in,
    output   logic   [31:0]     mem_wdata,
    output  logic [31:0]        aluout_out,
    output logic    [3:0]       mem_rmask_out,
    output logic    [3:0]       mem_wmask_out,
    output  logic [31:0]        mem_addr_out,
    output logic                stall_pipeline_out,
    input   logic   [31:0]      forward_from_mem,
    input   logic   [31:0]      forward_from_ex,
    input   logic               forward_ex_rs1_flag,
    input   logic               forward_ex_rs2_flag,
    input   logic               forward_mem_rs1_flag,
    input   logic               forward_mem_rs2_flag,
    output  logic   [31:0]      rvfi_ex_rs1_out,
    output  logic   [31:0]      rvfi_ex_rs2_out,
    output   pc_sel_t           pc_sel_mux_out,
    output logic                set_jump_flush,
    output logic                set_branch_flush,
    // output logic                set_branch_flush,
    output logic    [31:0]      jump_addr_out
   //output  logic               br_en_out
);

    logic          [31:0]   a;
    logic          [31:0]   b;
    logic signed   [31:0]   as;
    logic signed   [31:0]   bs;
    logic unsigned [31:0]   au;
    logic unsigned [31:0]   bu;

    logic          [31:0]   aluout;
    logic          [31:0]   rd_v;
    logic          [31:0]   rs1_vin;
    logic          [31:0]   rs2_vin;
    logic                   br_en;
    logic          [3:0]    mem_rmask;
    logic          [3:0]    mem_wmask;
    logic          [31:0]   mem_addr;

    logic stall_pipeline_exec;

    logic [31:0] get_jump_addr;


    always_comb begin
        if(forward_ex_rs1_flag && !forward_mem_rs1_flag) begin
            rs1_vin = forward_from_ex;
        end else if (forward_mem_rs1_flag && !forward_ex_rs1_flag) begin
            rs1_vin = forward_from_mem;
        end
        else begin
            rs1_vin = inst_info.rs1_v;
        end

        if(forward_ex_rs2_flag && !forward_mem_rs2_flag) begin
            rs2_vin = forward_from_ex;
        end else if (forward_mem_rs2_flag && !forward_ex_rs2_flag) begin
            rs2_vin = forward_from_mem;
        end
        else begin
            rs2_vin = inst_info.rs2_v;
        end
    end
    
    always_comb begin
        unique case (control_signals.alu_m1_sel)
        rs1_out: a = rs1_vin;
        pc_out:  a = pc_in;
        default: a = 'x;
        endcase
    end

    always_comb begin
        unique case (control_signals.alu_m2_sel)
        rs2_out: b = rs2_vin;
        imm_out: b = i_imm_in;
        j_imm_out: b = inst_info.j_imm;
        b_imm_out: b = inst_info.b_imm;
        default: b = 'x;
        endcase
    end

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    
    always_comb begin
        unique case (control_signals.aluop)
            alu_op_add: aluout = au +   bu;
            alu_op_sll: aluout = au <<  bu[4:0];
            alu_op_sra: aluout = unsigned'(as >>> bu[4:0]);
            alu_op_sub: aluout = au -   bu;
            alu_op_xor: aluout = au ^   bu;
            alu_op_srl: aluout = au >>  bu[4:0];
            alu_op_or : aluout = au |   bu;
            alu_op_and: aluout = au &   bu;
            default   : aluout = 'x;
        endcase

        unique case (control_signals.cmpop)
            branch_f3_beq : br_en = (au == bu);
            branch_f3_bne : br_en = (au != bu);
            branch_f3_blt : br_en = (as <  bs);
            branch_f3_bge : br_en = (as >=  bs);
            branch_f3_bltu: br_en = (au <  bu);
            branch_f3_bgeu: br_en = (au >=  bu);
            default       : br_en = 1'bx;
        endcase

    end

    always_comb begin
        mem_addr = '0;
        mem_rmask = '0;
        mem_wmask = '0;
        mem_wdata = '0;
        stall_pipeline_exec = '0;
        rd_v = '0;
        set_jump_flush = 1'b0;
        set_branch_flush = 1'b0;
        pc_sel_mux_out = pc_next_out;
        get_jump_addr = '0;
        unique case (inst_info.opcode)
            op_b_jal: begin
                pc_sel_mux_out = jump_out;
                get_jump_addr = pc_in + inst_info.j_imm;
                set_jump_flush = 1'b1;
            end

            op_b_jalr : begin
                pc_sel_mux_out = jump_out;
                get_jump_addr = rs1_vin + inst_info.i_imm;
                set_jump_flush = 1'b1;
            end

            op_b_br : begin
                get_jump_addr = pc_in + inst_info.b_imm;
                if(br_en) begin
                    pc_sel_mux_out = jump_out;
                    set_branch_flush = br_en;
                end
                else begin
                    pc_sel_mux_out = pc_next_out;
                end

                //this needs to be changed (dont return on a branch)
                //set_jump_flush = br_en;
            end

            op_b_load: begin
                    mem_addr = a + b;   //i_mm + rs1_v
                    unique case (inst_info.funct3)
                        load_f3_lb, load_f3_lbu: mem_rmask = 4'b0001 << mem_addr[1:0];
                        load_f3_lh, load_f3_lhu: mem_rmask = 4'b0011 << mem_addr[1:0];
                        load_f3_lw             : mem_rmask = 4'b1111;
                        default                : mem_rmask = '0;
                    endcase
                    //mem_addr[1:0] = 2'd0;
                    mem_wmask = '0;
                    stall_pipeline_exec = 1'b1;
            end
            
            op_b_store: begin
                    mem_addr = a + inst_info.s_imm;
                    unique case (inst_info.funct3) //rs1_v + s_imm 
                        store_f3_sb: mem_wmask = 4'b0001 << mem_addr[1:0];
                        store_f3_sh: mem_wmask = 4'b0011 << mem_addr[1:0];
                        store_f3_sw: mem_wmask = 4'b1111;
                        default    : mem_wmask = '0;
                    endcase
                    unique case (inst_info.funct3)
                        store_f3_sb: mem_wdata[8 *mem_addr[1:0] +: 8 ] = b[7 :0];
                        store_f3_sh: mem_wdata[16*mem_addr[1]   +: 16] = b[15:0];
                        store_f3_sw: mem_wdata = b;
                        default    : mem_wdata = '0;
                    endcase
                    //mem_addr[1:0] = 2'd0;
                    mem_rmask = '0;
                    stall_pipeline_exec = 1'b1;
            end

            op_b_reg: begin
                    unique case (inst_info.funct3)
                        arith_f3_slt: rd_v = {31'd0, br_en};
                        arith_f3_sltu: rd_v = {31'd0, br_en};
                        arith_f3_sr: rd_v = aluout;
                        arith_f3_add: rd_v = aluout;
                        default: rd_v = aluout;
                    endcase
                end
            
            op_b_imm: begin
                unique case (inst_info.funct3)
                    arith_f3_slt: rd_v = {31'd0, br_en};
                    arith_f3_sltu: rd_v = {31'd0, br_en};
                    arith_f3_sr: rd_v = aluout;
                    default: rd_v = aluout;
                endcase
                end

            op_b_auipc: begin
                rd_v = a + inst_info.u_imm;
            end
            
            op_b_lui: begin
                rd_v = inst_info.u_imm;
            end
            
            default: ;
            endcase
    end

    assign aluout_out = rd_v;
    assign mem_rmask_out = mem_rmask;
    assign mem_wmask_out = mem_wmask;
    assign mem_addr_out = mem_addr;

    assign stall_pipeline_out = stall_pipeline_exec;
    assign rvfi_ex_rs1_out = rs1_vin;
    assign rvfi_ex_rs2_out = rs2_vin;
    assign jump_addr_out = get_jump_addr;
    //assign br_en_out = br_en;

endmodule: execute