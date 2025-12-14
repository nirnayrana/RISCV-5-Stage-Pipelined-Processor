`timescale 1ns/1ns
module riscv_pipeline_top (
    input wire clk,
    input wire rst
);
    wire [31:0] PC_F, PC_Next_F, PC_Plus4_F;
    wire [31:0] Instr_F;
    riscv_pc PC_Module (
        .clk(clk),
        .rst(rst),
        .pc_next(PC_Next_F),
        .pc_current(PC_F)
    );
    assign PC_Plus4_F = PC_F + 4;
    assign PC_Next_F = (PCSrc_M) ? PCTarget_M : PC_Plus4_F; 
    riscv_imem IMEM (
        .a(PC_F),
        .rd(Instr_F)
    );
    wire [31:0] Instr_D;
    wire [31:0] PC_D;
    riscv_pipe_reg #(.N(64)) IF_ID_REG (
        .clk(clk),
        .rst(rst),
        .clear(1'b0), 
        .en(1'b1),          
        .d({Instr_F, PC_F}), 
        .q({Instr_D, PC_D})  
    );

    wire [6:0] opcode = Instr_D[6:0];
    wire [4:0] rd_D   = Instr_D[11:7];
    wire [2:0] funct3_D = Instr_D[14:12];
    wire [4:0] rs1_D  = Instr_D[19:15];
    wire [4:0] rs2_D  = Instr_D[24:20];
    wire [6:0] funct7_D = Instr_D[31:25];
    wire RegWrite_D, MemtoReg_D, MemWrite_D, ALUSrc_D, Branch_D;
    wire [1:0] ALUOp_D;
    riscv_control Control_Unit (
        .opcode(opcode),
        .Branch(Branch_D),
        .MemRead(),         // Not using MemRead logic for simplified version
        .MemtoReg(MemtoReg_D),
        .ALUOp(ALUOp_D),
        .MemWrite(MemWrite_D),
        .ALUSrc(ALUSrc_D),
        .RegWrite(RegWrite_D)
    );
    wire [31:0] RD1_D, RD2_D;
    wire [4:0]  RegWriteAddr_W; // From Stage 5
    wire [31:0] RegWriteData_W; // From Stage 5
    wire        RegWrite_W;     // From Stage 5
    riscv_regfile REG_FILE (
        .clk(clk),
        .we3(RegWrite_W),       // Writing happens in Stage 5
        .ra1(rs1_D),
        .ra2(rs2_D),
        .wa3(RegWriteAddr_W),
        .wd3(RegWriteData_W),
        .rd1(RD1_D),
        .rd2(RD2_D)
    );
    wire [31:0] Imm_D;
    riscv_imm_gen IMM_GEN (
        .inst(Instr_D),
        .imm_out(Imm_D)
    );
    wire [31:0] PC_E, RD1_E, RD2_E, Imm_E;
    wire [4:0]  rd_E, rs1_E, rs2_E; // Addresses needed for Hazard Unit later
    wire [2:0]  funct3_E;
    wire [6:0]  funct7_E;
    wire RegWrite_E, MemtoReg_E, MemWrite_E, ALUSrc_E, Branch_E;
    wire [1:0] ALUOp_E;
    riscv_pipe_reg #(.N(160)) ID_EX_REG (
        .clk(clk),
        .rst(rst),
        .clear(1'b0), // Flush signal for later
        .en(1'b1),    // Stall signal for later
        .d({RegWrite_D, MemtoReg_D, MemWrite_D, Branch_D, ALUSrc_D, ALUOp_D,  // Control
            PC_D, RD1_D, RD2_D, Imm_D,                                         // Data
            rd_D, rs1_D, rs2_D, funct3_D, funct7_D}),                          // Meta-Data
        .q({RegWrite_E, MemtoReg_E, MemWrite_E, Branch_E, ALUSrc_E, ALUOp_E,
            PC_E, RD1_E, RD2_E, Imm_E,
            rd_E, rs1_E, rs2_E, funct3_E, funct7_E})
    );
// ==========================================
    // STAGE 3: EXECUTE (E)
    // ==========================================

    // --- FORWARDING UNIT INSTANTIATION ---
    wire [1:0] ForwardA_E, ForwardB_E;
    
    riscv_forwarding FORWARD_UNIT (
        .rs1_E(rs1_E),
        .rs2_E(rs2_E),
        .rd_M(rd_M),
        .RegWrite_M(RegWrite_M),
        .rd_W(rd_W),
        .RegWrite_W(RegWrite_W),
        .ForwardA(ForwardA_E),
        .ForwardB(ForwardB_E)
    );

    // --- 3-WAY MUX FOR SOURCE A (rs1) ---
    reg [31:0] SrcA_Forwarded;
    always @(*) begin
        case (ForwardA_E)
            2'b00: SrcA_Forwarded = RD1_E;         // 00 = From RegFile
            2'b10: SrcA_Forwarded = ALUResult_M;   // 10 = Forward from Memory Stage
            2'b01: SrcA_Forwarded = Result_W;      // 01 = Forward from Writeback Stage
            default: SrcA_Forwarded = RD1_E;       // Default to RegFile
        endcase
    end

    // --- 3-WAY MUX FOR SOURCE B (rs2) ---
    // This generates the value 'WriteData_E' which acts as the input for the next Mux
    reg [31:0] WriteData_E; 
    always @(*) begin
        case (ForwardB_E)
            2'b00: WriteData_E = RD2_E;            // 00 = From RegFile
            2'b10: WriteData_E = ALUResult_M;      // 10 = Forward from Memory Stage
            2'b01: WriteData_E = Result_W;         // 01 = Forward from Writeback Stage
            default: WriteData_E = RD2_E;          // Default to RegFile
        endcase
    end

    // --- ALU SOURCE B MUX (Immediate Selection) ---
    // Critical Fix: Use WriteData_E (the forwarded value), NOT RD2_E
    wire [31:0] SrcB_E;
    assign SrcB_E = (ALUSrc_E) ? Imm_E : WriteData_E;

    // --- ALU CONTROL & CALCULATION ---
    wire [3:0] ALUControl_E;
    riscv_alu_decoder ALU_DEC (
        .alu_op(ALUOp_E),
        .funct3(funct3_E),
        .funct7(funct7_E[5]), // Fix: Pass only bit 5 (inst[30])
        .op(Instr_D[6:0]),
        .alu_ctrl(ALUControl_E)
    );

    wire [31:0] ALUResult_E;
    wire Zero_E;
    
    riscv_alu4b ALU (
        .a(SrcA_Forwarded),    // Use the Forwarded A
        .b(SrcB_E),            // Use the Forwarded/Immediate B
        .alu_ctrl(ALUControl_E),
        .result(ALUResult_E),
        .zero(Zero_E)
    );

    // --- BRANCH TARGET ---
    wire [31:0] PCTarget_E;
    assign PCTarget_E = PC_E + Imm_E;

    // ==========================================
    // PIPELINE REGISTER: EX / MEM
    // ==========================================
    wire RegWrite_M, MemtoReg_M, MemWrite_M, Branch_M, Zero_M;
    wire [31:0] ALUResult_M, WriteData_M, PCTarget_M;
    wire [4:0]  rd_M;

    riscv_pipe_reg #(.N(106)) EX_MEM_REG (
        .clk(clk),
        .rst(rst),
        .clear(1'b0),
        .en(1'b1),
        // PACK INPUTS: Use WriteData_E to ensure forwarded data is saved to memory during SW!
        .d({RegWrite_E, MemtoReg_E, MemWrite_E, Branch_E, Zero_E,
            ALUResult_E, WriteData_E, PCTarget_E, rd_E}), 
        // UNPACK OUTPUTS
        .q({RegWrite_M, MemtoReg_M, MemWrite_M, Branch_M, Zero_M,
            ALUResult_M, WriteData_M, PCTarget_M, rd_M})
    );
    wire [31:0] ReadData_M;
    riscv_dmem DMEM (
        .clk(clk),
        .we(MemWrite_M),
        .a(ALUResult_M),
        .wd(WriteData_M),
        .rd(ReadData_M)
    );
    wire PCSrc_M;
    assign PCSrc_M = Branch_M & Zero_M;
    wire MemtoReg_W; 
    wire [31:0] ALUResult_W, ReadData_W;
    wire [4:0]  rd_W;
    riscv_pipe_reg #(.N(71)) MEM_WB_REG (
        .clk(clk),
        .rst(rst),
        .clear(1'b0),
        .en(1'b1),
        .d({RegWrite_M, MemtoReg_M, ALUResult_M, ReadData_M, rd_M}),
        .q({RegWrite_W, MemtoReg_W, ALUResult_W, ReadData_W, rd_W})
    );
    wire [31:0] Result_W;
    assign Result_W = (MemtoReg_W) ? ReadData_W : ALUResult_W;
    assign RegWriteAddr_W = rd_W;   // "Write to Register Number X"
    assign RegWriteData_W = Result_W; // "Write this Value"
endmodule