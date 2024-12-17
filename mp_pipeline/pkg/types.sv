/////////////////////////////////////////////////////////////
// Maybe merge what is in mp_verif/pkg/types.sv over here? //
/////////////////////////////////////////////////////////////

package rv32i_types;

    //RVFI signals struct
    typedef struct packed {

        logic           monitor_valid;      //assigned in wb stage
        logic   [63:0]  monitor_order;      //assigned in wb stage
        logic   [31:0]  monitor_inst;       //assigned in decode stage
        logic   [4:0]   monitor_rs1_addr;   //assigned in decode stage
        logic   [4:0]   monitor_rs2_addr;   //assigned in decode stage
        logic   [31:0]  monitor_rs1_rdata;  //assigned in execute stage
        logic   [31:0]  monitor_rs2_rdata;  //assigned in execute stage
        logic           monitor_regf_we;    //assigned in decode stage
        
        logic   [4:0]   monitor_rd_addr;    //assigned in decode stage
        logic   [31:0]  monitor_rd_wdata;   //assigned in execute stage
        logic   [31:0]  monitor_pc_rdata;   //assigned in fetch (pc)
        logic   [31:0]  monitor_pc_wdata;   //assigned in fetch (pc_next)
        
        logic   [31:0]  monitor_mem_addr; 
        logic   [3:0]   monitor_mem_rmask;
        logic   [3:0]   monitor_mem_wmask;
        logic   [31:0]  monitor_mem_rdata;
        logic   [31:0]  monitor_mem_wdata;

    } rvfi_signals_t;


    typedef enum logic {
        rs1_out = 1'b0,
        pc_out  = 1'b1
    } alu_m1_sel_t;

    typedef enum logic [1:0] {
        rs2_out = 2'b00,
        imm_out = 2'b01,
        j_imm_out = 2'b10,
        b_imm_out = 2'b11
    } alu_m2_sel_t;

    typedef enum logic { 
        pc_next_out = 1'b0,
        jump_out = 1'b1
    } pc_sel_t;

    // typedef enum logic [1:0]{
    //     aluout = 2'b00,
    //     dataout = 2'b01,
    //     pc_nextout = 2'b10
    // } mem_wb_sel_t;

// typedef struct packed {
//     logic br_en;
//     logic [31:0] new_pc;
//     logic [63:0] new_order;
// } save_on_control_t;


    //control word struct
    typedef struct packed {
        logic       regf_we;
        logic       br_en;

        logic [2:0] aluop;
        logic [2:0] cmpop;
        
        alu_m1_sel_t        alu_m1_sel;
        alu_m2_sel_t        alu_m2_sel;
        // mem_wb_sel_t        mem_wb_sel;

    } control_word_t;


    typedef struct packed {
        //instruction breakdown
        logic   [31:0]      inst;
        logic   [6:0]       opcode;
        logic   [6:0]       funct7;
        logic   [2:0]       funct3;
        logic   [31:0]      i_imm;
        logic   [31:0]      u_imm;
        logic   [31:0]      s_imm;
        logic   [31:0]      b_imm;
        logic   [31:0]      j_imm;
        logic   [31:0]      rs1_v;
        logic   [31:0]      rs2_v;
        logic   [4:0]       rs1_s;
        logic   [4:0]       rs2_s;
        logic   [4:0]       rd_s;

        logic   [31:0]      jump_pc;
    } inst_breakdown_t;



    typedef struct packed {
        logic   [31:0]      pc;
        logic   [31:0]      pc_next;

        inst_breakdown_t inst_info;
        control_word_t control;
        rvfi_signals_t rvfi_signals;
        
    } if_id_stage_reg_t;


    typedef struct packed {
        //get stuff from before
        logic   [31:0]      pc;
        logic   [31:0]      pc_next;

        control_word_t      control;
        rvfi_signals_t      rvfi_signals;
        inst_breakdown_t    inst_info;
    } id_ex_stage_reg_t;


    typedef struct packed {
        //get stuff from fetch
        logic   [31:0]      pc;
        logic   [31:0]      pc_next;

        //same control signals from before
        control_word_t control;

        //same instruction breakdown from before
        inst_breakdown_t inst_info;
        rvfi_signals_t rvfi_signals;

        logic stall_pipeline;

        logic   [31:0]      rs1_v;
        logic   [31:0]      rs2_v;
        logic   [31:0]      rd_v;

        logic   [3:0] rmask_decode;
        logic   [3:0] wmask_decode;
        logic   [31:0] addr_decode;
        
    } ex_mem_stage_reg_t;


    typedef struct packed {
        //get stuff from fetch
        logic   [31:0]      pc;
        logic   [31:0]      pc_next;

        //same control signals as before
        control_word_t control;

        inst_breakdown_t inst_info;

        rvfi_signals_t rvfi_signals;

        logic   [31:0]      rs1_v;
        logic   [31:0]      rs2_v;
        logic   [31:0]      rd_v;

        // logic   [3:0]       rmask_decode;
        // logic   [3:0]       wmask_decode;
        // logic   [31:0]      addr_decode; 
        
    } mem_wb_stage_reg_t;

    typedef enum logic [6:0] {
        op_b_lui       = 7'b0110111, // load upper immediate (U type)
        op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
        op_b_jal       = 7'b1101111, // jump and link (J type)
        op_b_jalr      = 7'b1100111, // jump and link register (I type)
        op_b_br        = 7'b1100011, // branch (B type)
        op_b_load      = 7'b0000011, // load (I type)
        op_b_store     = 7'b0100011, // store (S type)
        op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
        op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
    } rv32i_opcode;

    typedef enum logic [2:0] {
        arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;

    typedef enum logic [2:0] {
        alu_op_add     = 3'b000,
        alu_op_sll     = 3'b001,
        alu_op_sra     = 3'b010,
        alu_op_sub     = 3'b011,
        alu_op_xor     = 3'b100,
        alu_op_srl     = 3'b101,
        alu_op_or      = 3'b110,
        alu_op_and     = 3'b111
    } alu_ops;

    typedef enum logic [2:0] {
        load_f3_lb     = 3'b000,
        load_f3_lh     = 3'b001,
        load_f3_lw     = 3'b010,
        load_f3_lbu    = 3'b100,
        load_f3_lhu    = 3'b101
    } load_f3_t;

    typedef enum logic [2:0] {
        store_f3_sb    = 3'b000,
        store_f3_sh    = 3'b001,
        store_f3_sw    = 3'b010
    } store_f3_t;


   typedef enum logic [2:0] {
        branch_f3_beq  = 3'b000,
        branch_f3_bne  = 3'b001,
        branch_f3_blt  = 3'b100,
        branch_f3_bge  = 3'b101,
        branch_f3_bltu = 3'b110,
        branch_f3_bgeu = 3'b111
    } branch_f3_t;

    typedef enum logic [6:0] {
        base           = 7'b0000000,
        variant        = 7'b0100000
    } funct7_t;

    
    typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } r_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } j_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } u_type;

    } instr_t;

endpackage
