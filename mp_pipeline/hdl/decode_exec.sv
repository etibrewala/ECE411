module decode
import rv32i_types::*;
(
    input   logic               [31:0]  inst_in,
    // input   logic               [31:0]  pc_in,
    // input   logic               [31:0]  rs1_in,
    output  logic               [4:0]   rd_sout,
    output  logic               [4:0]   rs1_sout,
    output  logic               [4:0]   rs2_sout,
    output  logic                       regf_we_out,
    output  inst_breakdown_t            inst_sig_out,
    output  control_word_t              control_sig_out
);


            logic           load_ir;
            logic   [31:0]  inst;
            logic   [2:0]   funct3;
            logic   [6:0]   funct7;
            logic   [6:0]   opcode;

            logic   [31:0]  i_imm;
            logic   [31:0]  u_imm;
            logic   [31:0]  s_imm;
            logic   [31:0]  b_imm;
            logic   [31:0]  j_imm;

            logic   [4:0]   rs1_s;
            logic   [4:0]   rs2_s;
            logic   [4:0]   rd_s;

            logic           regf_we;

            logic   [2:0]   aluop;
            logic   [2:0]   cmpop;

            // logic   [31:0]  jump_pc;

    
        assign funct3 = inst_in[14:12];
        assign funct7 = inst_in[31:25];
        assign opcode = inst_in[6:0];

        assign i_imm  = {{21{inst_in[31]}}, inst_in[30:20]};
        assign s_imm  = {{21{inst_in[31]}}, inst_in[30:25], inst_in[11:7]};
        assign u_imm  = {inst_in[31:12], 12'h000};
        assign b_imm  = {{20{inst_in[31]}}, inst_in[7], inst_in[30:25], inst_in[11:8], 1'b0};
        assign j_imm  = {{12{inst_in[31]}}, inst_in[19:12], inst_in[20], inst_in[30:21], 1'b0};

    always_comb begin
        aluop = '0;
        cmpop = '0;
        regf_we = '0;
        // jump_pc = '0;
        rs1_s  = inst_in[19:15];
        rs2_s  = inst_in[24:20];
        rd_s   = inst_in[11:7];
        control_sig_out.alu_m2_sel = rs2_out;
        control_sig_out.alu_m1_sel = rs1_out;
        unique case (opcode)
            op_b_load: begin
                control_sig_out.alu_m1_sel = rs1_out;
                control_sig_out.alu_m2_sel = imm_out;
                regf_we = 1'b1;
            end
            
            op_b_store: begin
                control_sig_out.alu_m1_sel = rs1_out;
                control_sig_out.alu_m2_sel = rs2_out;
            end
            
            op_b_jal : begin
                regf_we =  1'b1;
                // jump_pc = pc_in + j_imm;
                control_sig_out.alu_m1_sel = pc_out;
                control_sig_out.alu_m2_sel = j_imm_out;
            end

            op_b_jalr : begin
                regf_we = 1'b1;
                control_sig_out.alu_m1_sel = rs1_out;
                control_sig_out.alu_m2_sel = imm_out;
                // jump_pc = (rs1_in + i_imm) & 32'hfffffffe;
                cmpop = funct3;
            end

            op_b_br : begin
                // jump_pc = pc_in + b_imm;
                cmpop = funct3;
                control_sig_out.alu_m1_sel = rs1_out;
                control_sig_out.alu_m2_sel = rs2_out;
            end

            op_b_reg: begin
                    unique case (funct3)
                        arith_f3_slt: cmpop = branch_f3_blt;
                        arith_f3_sltu: cmpop = branch_f3_bltu;
                        arith_f3_sr: begin
                            if (funct7[5]) begin
                                aluop = alu_op_sra;
                            end else begin
                                aluop = alu_op_srl;
                            end
                        end
                        arith_f3_add: begin
                            if (funct7[5]) begin
                                aluop = alu_op_sub;
                            end else begin
                                aluop = alu_op_add;
                            end
                        end
                        default: aluop = funct3;
                    endcase
                    regf_we = 1'b1;
                    control_sig_out.alu_m1_sel = rs1_out;
                    control_sig_out.alu_m2_sel = rs2_out;
            end
        
            op_b_imm: begin
                unique case (funct3)
                    arith_f3_slt: cmpop = branch_f3_blt;
                    arith_f3_sltu: cmpop = branch_f3_bltu;

                    arith_f3_sr: begin
                        if (funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                    end
                    default: begin
                        aluop = funct3;
                        cmpop = '0;
                    end
                endcase
                regf_we = 1'b1;
                control_sig_out.alu_m1_sel = rs1_out;
                control_sig_out.alu_m2_sel = imm_out;
                rs2_s = '0;
            end
        
            op_b_lui: begin
                regf_we = 1'b1;
                control_sig_out.alu_m1_sel = pc_out;
                control_sig_out.alu_m2_sel = imm_out;
                rs1_s = '0;
                rs2_s = '0;
            end

            op_b_auipc: begin
                regf_we = 1'b1;
                control_sig_out.alu_m1_sel = pc_out;
                control_sig_out.alu_m2_sel = imm_out;
                rs1_s = '0;
                rs2_s = '0;
            end

            default: begin
                // aluop = funct3;
                // cmpop = 'x;
                // regf_we = 1'b0;
                //NEED TO CHANGE THIS LATER
                // control_sig_out.alu_m2_sel = rs2_out;
                // control_sig_out.alu_m1_sel = rs1_out;
            end
            
        endcase
    end

assign rd_sout     = rd_s;
assign regf_we_out = regf_we;
assign rs1_sout    = rs1_s;
assign rs2_sout    = rs2_s;

//assigning control signals
assign control_sig_out.regf_we = regf_we;
assign control_sig_out.aluop = aluop;
assign control_sig_out.cmpop = cmpop;
assign control_sig_out.br_en = 1'b0;

// assign control_sig_out.alu_m1_sel = rs1_out;
assign inst_sig_out.opcode = opcode;
assign inst_sig_out.funct7 = funct7;
assign inst_sig_out.funct3 = funct3;
assign inst_sig_out.i_imm = i_imm;
assign inst_sig_out.u_imm = u_imm;
assign inst_sig_out.s_imm = s_imm;
assign inst_sig_out.b_imm = b_imm;
assign inst_sig_out.j_imm = j_imm;
assign inst_sig_out.rs1_s = rs1_s;
assign inst_sig_out.rs2_s = rs2_s;
assign inst_sig_out.rd_s = rd_s;
assign inst_sig_out.jump_pc = '0;

// assign inst_sig_out.jump_pc = jump_pc;


endmodule: decode