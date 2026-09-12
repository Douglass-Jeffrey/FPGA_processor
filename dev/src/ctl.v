`include "defines.vh"
module ctl (
    input wire [6:0]    opcode,        //from instr
    input wire [2:0]    funct3,        //from instr[14:12], to split SYSTEM opcode
    output reg          branch,        //to pc_mux
    output reg          jump,      //to data_mem
    output reg          mem_read,      //to data_mem
    output reg [1:0]    wb_src,        //to wb_mux
    output reg [1:0]    alu_op,        //to alu_ctl
    output reg          mem_write,     //to data_mem
    output reg          alu_src,       //to alu_rd2_mux (use data2 or imm)
    output reg          reg_write,     //to regfile
    output reg [2:0]    imm_type,      //to imm_gen
    output reg          alu_a_src,     
    output reg          jalr
);
    always @(*) begin
        //default values
        branch     = 1'b0; 
        jump       = 1'b0;
        mem_read   = 1'b0;
        wb_src     = `WB_ALU;
        alu_op     = `ALUOP_ADD;
        mem_write  = 1'b0;
        alu_src    = 1'b0;
        reg_write  = 1'b0;
        imm_type   = `IMM_I;
        alu_a_src  = `ALU_A_RS1;
        jalr       = 1'b0;

        case (opcode)
            `BRANCH_OPCODE: begin
                branch      = 1'b1;
                alu_op      = `ALUOP_BRANCH;
                imm_type    = `IMM_B;
            end
            `LOAD_OPCODE: begin
                mem_read    = 1'b1;
                wb_src      = `WB_MEM;
                alu_op      = `ALUOP_ADD; //load
                alu_src     = 1'b1;
                reg_write   = 1'b1;
                imm_type     = `IMM_I;
            end
            `STORE_OPCODE: begin
                alu_op      = `ALUOP_ADD; //store
                mem_write   = 1'b1;
                alu_src     = 1'b1;
                reg_write   = 1'b0;
                imm_type     = `IMM_S;
            end
            `RTYPE_OPCODE: begin
                alu_op      = `ALUOP_RTYPE; //rtype
                alu_src     = 1'b0;
                reg_write   = 1'b1;
            end
            `IMM_OPCODE: begin
                alu_op      = `ALUOP_RTYPE; //rtype
                alu_src     = 1'b1;
                reg_write   = 1'b1;
                imm_type     = `IMM_I;
            end
            `JAL_OPCODE: begin
                jump        = 1'b1;
                alu_op      = `ALUOP_ADD; //jal
                alu_src     = 1'b1;
                reg_write   = 1'b1;
                imm_type     = `IMM_J;
                wb_src      = `WB_PC4; //rd = pc+4, target comes from pc_target
            end
            `JALR_OPCODE: begin
                jump        = 1'b1;
                jalr        = 1'b1; //target = (rs1+immI) & ~1, not pc+imm
                alu_op      = `ALUOP_ADD; //jalr
                alu_src     = 1'b1;
                reg_write   = 1'b1;
                imm_type    = `IMM_I;
                wb_src      = `WB_PC4; //rd = pc+4
            end
            `LUI_OPCODE: begin
                alu_src     = 1'b1;
                reg_write   = 1'b1;
                imm_type    = `IMM_U;
                wb_src      = `WB_IMM; //rd = imm (no rs1 term)
            end
            `AUIPC_OPCODE: begin
                alu_src     = 1'b1;
                alu_a_src   = `ALU_A_PC; //rd = pc + imm
                alu_op      = `ALUOP_ADD; //auipc
                reg_write   = 1'b1;
                imm_type    = `IMM_U;
            end
            `FENCE_OPCODE: begin
                branch      = 1'b0;
                mem_read    = 1'b0;
                wb_src      = `WB_ALU; //fence
                alu_op      = `ALUOP_ADD; //fence
                mem_write   = 1'b0;
                alu_src     = 1'b0;
                reg_write   = 1'b0;
            end
            `SYSTEM_OPCODE: begin
                // funct3 == 000 : ECALL / EBREAK / xRET -> no trap support, treat as NOP.
                // funct3 != 000 : CSRRW/S/C[I] -> old CSR value is written back to rd.
                // out of scope for now but maybe in future
                if (funct3 != 3'b000) begin
                    reg_write = 1'b1;
                end
            end
            default: begin
                branch      = 1'b0;
                mem_read    = 1'b0;
                wb_src      = `WB_ALU; //default to ALU
                alu_op      = `ALUOP_ADD; //default to add
                mem_write   = 1'b0;
                alu_src     = 1'b0;
                reg_write   = 1'b0;
            end
        endcase
    end
endmodule