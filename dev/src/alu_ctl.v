`include "defines.vh"

module alu_ctl (
    input wire [1:0] alu_op_from_ctl,   //from main ctl
    input wire [2:0] funct3,            //from instr
    input wire funct7b5,                //from instr, bit 30 
    input wire is_rtype,                //from main ctl
    output reg [3:0] alu_op             //to alu
);
always @(*) begin
    case (alu_op_from_ctl)
        `ALUOP_ADD: begin
            alu_op = `ALU_ADD; //add
        end
        `ALUOP_BRANCH: begin
            case (funct3)
                3'b000: alu_op = `ALU_SUB;   // beq check zero
                3'b001: alu_op = `ALU_SUB;   // bne check !zero
                3'b100: alu_op = `ALU_SLT;   // blt check result==1
                3'b101: alu_op = `ALU_SLT;   // bge check result==0 (i.e. !(a<b))
                3'b110: alu_op = `ALU_SLTU;  // bltu
                3'b111: alu_op = `ALU_SLTU;  // bgeu
                default: alu_op = `ALU_SUB;
            endcase
        end
        `ALUOP_RTYPE: begin
            case (funct3)
                3'b000: alu_op = (is_rtype && funct7b5) ? `ALU_SUB : `ALU_ADD;
                3'b001: alu_op = `ALU_SLL;
                3'b010: alu_op = `ALU_SLT;
                3'b011: alu_op = `ALU_SLTU;
                3'b100: alu_op = `ALU_XOR;
                3'b101: alu_op = funct7b5 ? `ALU_SRA : `ALU_SRL;
                3'b110: alu_op = `ALU_OR;
                3'b111: alu_op = `ALU_AND;
                default: alu_op = `ALU_ADD;
            endcase
        end
        default: begin
            alu_op = `ALU_ADD;
        end
    endcase
end
endmodule