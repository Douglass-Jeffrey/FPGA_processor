`include "defines.vh"

//single-cycle RV32I datapath
module top (
    input  wire        clk,
    input  wire        rst,
    // observation ports for a testbench
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire [31:0] dbg_wb_data,
    output wire        dbg_reg_write
);

    // Program counter
    reg  [31:0] pc;
    reg  [31:0] next_pc;

    always @(posedge clk or posedge rst) begin
        if (rst) pc <= 32'h0000_0000;
        else     pc <= next_pc;
    end

    // Instruction memory
    wire [31:0] instr;
    imem #(
        .DEPTH_WORDS (512),
        .INIT_FILE   ("program.hex")
    ) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // Instruction field extraction
    wire [6:0] opcode   = instr[6:0];
    wire [4:0] rd_addr  = instr[11:7];
    wire [2:0] funct3   = instr[14:12];
    wire [4:0] rs1_addr = instr[19:15];
    wire [4:0] rs2_addr = instr[24:20];
    wire       funct7b5 = instr[30];
    wire       is_rtype = (opcode == `RTYPE_OPCODE);

    // Main control
    wire        branch, jump, jalr;
    wire        mem_read, mem_write;
    wire        alu_src, alu_a_src, reg_write;
    wire [1:0]  wb_src;
    wire [1:0]  alu_op_ctl;
    wire [2:0]  imm_type;

    ctl u_ctl (
        .opcode    (opcode),
        .funct3    (funct3),
        .branch    (branch),
        .jump      (jump),
        .mem_read  (mem_read),
        .wb_src    (wb_src),
        .alu_op    (alu_op_ctl),
        .mem_write (mem_write),
        .alu_src   (alu_src),
        .reg_write (reg_write),
        .imm_type  (imm_type),
        .alu_a_src (alu_a_src),
        .jalr      (jalr)
    );

    // Immediate generator
    wire [31:0] imm;
    imm_gen u_imm (
        .instr    (instr),
        .imm_type (imm_type),
        .imm      (imm)
    );

    // Register file
    wire [31:0] rs1_data, rs2_data;
    reg  [31:0] wb_data;

    regfile u_rf (
        .clk      (clk),
        .rst      (rst),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (wb_data),
        .rd_we    (reg_write),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ALU operation decode and ALU
    wire [3:0] alu_op;
    alu_ctl u_alu_ctl (
        .alu_op_from_ctl (alu_op_ctl),
        .funct3          (funct3),
        .funct7b5        (funct7b5),
        .is_rtype        (is_rtype),
        .alu_op          (alu_op)
    );

    wire [31:0] alu_a = (alu_a_src == `ALU_A_PC) ? pc  : rs1_data;
    wire [31:0] alu_b =  alu_src                 ? imm : rs2_data;

    wire [31:0] alu_result;
    wire        zero_flag;
    alu u_alu (
        .a         (alu_a),
        .b         (alu_b),
        .alu_op    (alu_op),
        .result    (alu_result),
        .zero_flag (zero_flag)
    );

    //branch resolver  
    reg cond;
    always @(*) begin
        case (funct3)
            3'b000: cond =  zero_flag;   // BEQ
            3'b001: cond = ~zero_flag;   // BNE
            3'b100: cond = ~zero_flag;   // BLT
            3'b101: cond =  zero_flag;   // BGE
            3'b110: cond = ~zero_flag;   // BLTU
            3'b111: cond =  zero_flag;   // BGEU
            default: cond = 1'b0;
        endcase
    end
    wire take_branch = branch & cond;

    // Next-PC mux
    wire [31:0] pc_plus4    = pc + 32'd4;
    wire [31:0] pc_target   = pc + imm;                  // branch immB / JAL immJ
    wire [31:0] jalr_target = {alu_result[31:1], 1'b0};  // rs1 + immI, bit 0 cleared

    always @(*) begin
        if      (jump && jalr)        next_pc = jalr_target;
        else if (jump || take_branch) next_pc = pc_target;
        else                          next_pc = pc_plus4;
    end

    // Data memory
    wire [31:0] load_data;
    dmem #(
        .DEPTH_WORDS (256)
    ) u_dmem (
        .clk       (clk),
        .addr      (alu_result),
        .funct3    (funct3),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .wdata     (rs2_data),
        .rdata     (load_data)
    );

    // Write-back mux
    always @(*) begin
        case (wb_src)
            `WB_ALU: wb_data = alu_result;
            `WB_MEM: wb_data = load_data;
            `WB_PC4: wb_data = pc_plus4;
            `WB_IMM: wb_data = imm;
            default: wb_data = alu_result;
        endcase
    end

    // Debug taps
    assign dbg_pc        = pc;
    assign dbg_instr     = instr;
    assign dbg_wb_data   = wb_data;
    assign dbg_reg_write = reg_write;

endmodule
