`timescale 1ns/1ns
module riscv_pipeline_top (
    input wire clk,
    input wire rst
);

    // ==========================================
    // STAGE 1: FETCH (F)
    // ==========================================
    wire [31:0] PC_F, PC_Next_F, PC_Plus4_F;
    wire [31:0] Instr_F;
    wire [31:0] PCTarget_M;
    wire PCSrc_M;
    wire [4:0] rd_M;
    wire RegWrite_M;
    wire [4:0] rd_W;
    wire RegWrite_W;
    
    // --- CSR MODIFICATION: Trap Handling Logic ---
    wire [31:0] CSR_mtvec, CSR_mepc;
    wire        Trap_Take; // Signal to jump to Trap Vector
    wire [31:0] Exception_Code = 32'd2; 

    // 2. Trigger Logic
    // We trap if the Control Unit says "Illegal"
    assign Trap_Take = IllegalInst_D & (Instr_D!=32'h0)&(Instr_D[0]!==1'bx)& !rst;
    
    // Mux to choose next PC: Normal Branch vs Trap (Exception)
    wire [31:0] PC_Target_Final;
    assign PC_Target_Final = (Trap_Take) ? 32'h00000014 : 
                             (PCSrc_M)   ? PCTarget_M : PC_Plus4_F; 

    // Note: We used PC_Target_Final instead of simple PCSrc_M logic
    assign PC_Next_F = PC_Target_Final;

    riscv_pc PC_Module (
        .clk(clk),
        .rst(rst),
        .pc_next(PC_Next_F),
        .pc_current(PC_F)
    );

    assign PC_Plus4_F = PC_F + 4;

    riscv_imem IMEM (
        .a(PC_F),
        .rd(Instr_F)
    );

    // ==========================================
    // PIPELINE REGISTER: IF / ID
    // ==========================================
    wire [31:0] Instr_D;
    wire [31:0] PC_D;
    wire [31:0] Instr_F_Clean;
    assign Instr_F_Clean = (Trap_Take) ? 32'h00000013 : Instr_F;

    riscv_pipe_reg #(.N(64)) IF_ID_REG (
        .clk(clk),
        .rst(rst),
        .clear(Trap_Take), // Flush pipeline if Trap occurs
        .en(1'b1),          
        .d({Instr_F_Clean, PC_F}), 
        .q({Instr_D, PC_D})  
    );

    // ==========================================
    // STAGE 2: DECODE (D)
    // ==========================================
    wire [6:0] opcode = Instr_D[6:0];
    wire [4:0] rd_D   = Instr_D[11:7];
    wire [2:0] funct3_D = Instr_D[14:12];
    wire [4:0] rs1_D  = Instr_D[19:15];
    wire [4:0] rs2_D  = Instr_D[24:20];
    wire [6:0] funct7_D = Instr_D[31:25];

    wire RegWrite_D, MemtoReg_D, MemWrite_D, ALUSrc_D, Branch_D;
    wire [1:0] ALUOp_D;
    
    // --- CSR MODIFICATION: New Control Signals ---
    wire CSRWrite_D; // Needs to be added to Control Unit logic!
    wire CSRRead_D;  // Needs to be added to Control Unit logic!
    wire IllegalInst_D;

    riscv_control Control_Unit (
        .opcode(opcode),
        .funct3(funct3_D),
        .Branch(Branch_D),
        .MemRead(),         
        .MemtoReg(MemtoReg_D),
        .ALUOp(ALUOp_D),
        .MemWrite(MemWrite_D),
        .ALUSrc(ALUSrc_D),
        .RegWrite(RegWrite_D),
        .CSRWrite(CSRWrite_D),   // Connect to the wire we defined
        .CSRRead(CSRRead_D),     // Connect to the wire we defined
        .IsMRET(),
        .IllegalInst(IllegalInst_D)

        // .CSRWrite(CSRWrite_D)  <-- You must add this port to your Control Unit!
        // .CSRRead(CSRRead_D)    <-- You must add this port to your Control Unit!
    );

    // NOTE: For now, we manually derive CSRWrite if you haven't updated Control Unit yet
    assign CSRWrite_D = (opcode == 7'b1110011) && (funct3_D != 3'b000); // System Opcode

    wire [31:0] RD1_D, RD2_D;
    wire [4:0]  RegWriteAddr_W; // From Stage 5
    wire [31:0] RegWriteData_W; // From Stage 5

    riscv_regfile REG_FILE (
        .clk(clk),
        .we3(RegWrite_W),       
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

    // --- CSR MODIFICATION: Prepare Signals for Pipeline ---
    wire [11:0] CSR_Addr_D = Instr_D[31:20]; // Address of CSR (e.g., 0x305 for mtvec)

    // ==========================================
    // PIPELINE REGISTER: ID / EX
    // ==========================================
    wire [31:0] PC_E, RD1_E, RD2_E, Imm_E;
    wire [4:0]  rd_E, rs1_E, rs2_E;
    wire [2:0]  funct3_E;
    wire [6:0]  funct7_E;
    wire RegWrite_E, MemtoReg_E, MemWrite_E, ALUSrc_E, Branch_E;
    wire [1:0] ALUOp_E;
    
    // CSR Pipeline Signals
    wire [11:0] CSR_Addr_E;
    wire        CSRWrite_E;

    // Added 13 bits to width (12 addr + 1 WE) -> N = 160 + 13 = 173
    riscv_pipe_reg #(.N(173)) ID_EX_REG (
        .clk(clk),
        .rst(rst),
        .clear(Trap_Take), 
        .en(1'b1),    
        .d({CSRWrite_D, CSR_Addr_D,      // <-- Added CSR Signals
            RegWrite_D, MemtoReg_D, MemWrite_D, Branch_D, ALUSrc_D, ALUOp_D,  
            PC_D, RD1_D, RD2_D, Imm_D,                                         
            rd_D, rs1_D, rs2_D, funct3_D, funct7_D}),                          
        .q({CSRWrite_E, CSR_Addr_E,      // <-- unpacked CSR Signals
            RegWrite_E, MemtoReg_E, MemWrite_E, Branch_E, ALUSrc_E, ALUOp_E,
            PC_E, RD1_E, RD2_E, Imm_E,
            rd_E, rs1_E, rs2_E, funct3_E, funct7_E})
    );

    // ==========================================
    // STAGE 3: EXECUTE (E)
    // ==========================================

    // --- FORWARDING UNIT INSTANTIATION ---
    wire [1:0] ForwardA_E, ForwardB_E;
     // Forward declaration needed

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
    wire [31:0] ALUResult_M; // Forward declaration
    wire [31:0] Result_W;    // Forward declaration

    always @(*) begin
        case (ForwardA_E)
            2'b00: SrcA_Forwarded = RD1_E;         
            2'b10: SrcA_Forwarded = ALUResult_M;   
            2'b01: SrcA_Forwarded = Result_W;      
            default: SrcA_Forwarded = RD1_E;       
        endcase
    end

    // --- 3-WAY MUX FOR SOURCE B (rs2) ---
    reg [31:0] WriteData_E; 
    always @(*) begin
        case (ForwardB_E)
            2'b00: WriteData_E = RD2_E;            
            2'b10: WriteData_E = ALUResult_M;      
            2'b01: WriteData_E = Result_W;         
            default: WriteData_E = RD2_E;          
        endcase
    end

    // --- ALU SOURCE B MUX ---
    wire [31:0] SrcB_E;
    assign SrcB_E = (ALUSrc_E) ? Imm_E : WriteData_E;

    // --- ALU CONTROL ---
    wire [3:0] ALUControl_E;
    riscv_alu_decoder ALU_DEC (
        .alu_op(ALUOp_E),
        .funct3(funct3_E),
        .funct7(funct7_E[5]), 
        .op(Instr_D[6:0]), // Note: Ideally pass Opcode through pipeline too
        .alu_ctrl(ALUControl_E)
    );

    wire [31:0] ALUResult_E;
    wire Zero_E;
    
    riscv_alu4b ALU (
        .a(SrcA_Forwarded),    
        .b(SrcB_E),            
        .alu_ctrl(ALUControl_E),
        .result(ALUResult_E),
        .zero(Zero_E)
    );

    wire [31:0] PCTarget_E;
    assign PCTarget_E = PC_E + Imm_E;

    // ==========================================
    // PIPELINE REGISTER: EX / MEM
    // ==========================================
    wire MemtoReg_M, MemWrite_M, Branch_M, Zero_M;
    wire [31:0] WriteData_M;
    
    // CSR Pipeline Signals (EX -> MEM)
    wire [11:0] CSR_Addr_M;
    wire        CSRWrite_M;
    wire [31:0] CSR_WriteData_M = SrcA_Forwarded; // CSRRW instruction writes value from RS1 to CSR

    // Added 13+32 bits -> N = 106 + 45 = 151
    riscv_pipe_reg #(.N(151)) EX_MEM_REG (
        .clk(clk),
        .rst(rst),
        .clear(Trap_Take),
        .en(1'b1),
        // PACK INPUTS
        .d({CSRWrite_E, CSR_Addr_E, CSR_WriteData_M, // <-- Added CSR
            RegWrite_E, MemtoReg_E, MemWrite_E, Branch_E, Zero_E,
            ALUResult_E, WriteData_E, PCTarget_E, rd_E}), 
        // UNPACK OUTPUTS
        .q({CSRWrite_M, CSR_Addr_M, CSR_WriteData_M, // <-- Unpacked CSR
            RegWrite_M, MemtoReg_M, MemWrite_M, Branch_M, Zero_M,
            ALUResult_M, WriteData_M, PCTarget_M, rd_M})
    );

    // ==========================================
    // STAGE 4: MEMORY (M)
    // ==========================================
    wire [31:0] ReadData_M;
    
    riscv_dmem DMEM (
        .clk(clk),
        .we(MemWrite_M),
        .a(ALUResult_M),
        .wd(WriteData_M),
        .rd(ReadData_M)
    );

    assign PCSrc_M = Branch_M & Zero_M;

    // ==========================================
    // PIPELINE REGISTER: MEM / WB
    // ==========================================
    wire MemtoReg_W; 
    wire [31:0] ALUResult_W, ReadData_W;
    
    // CSR Pipeline Signals (MEM -> WB)
    wire [11:0] CSR_Addr_W;
    wire        CSRWrite_W;
    wire [31:0] CSR_WriteData_W;

    // Added 45 bits -> N = 71 + 45 = 116
    riscv_pipe_reg #(.N(116)) MEM_WB_REG (
        .clk(clk),
        .rst(rst),
        .clear(Trap_Take),
        .en(1'b1),
        .d({CSRWrite_M, CSR_Addr_M, CSR_WriteData_M, // <-- Added CSR
            RegWrite_M, MemtoReg_M, ALUResult_M, ReadData_M, rd_M}),
        .q({CSRWrite_W, CSR_Addr_W, CSR_WriteData_W, // <-- Unpacked CSR
            RegWrite_W, MemtoReg_W, ALUResult_W, ReadData_W, rd_W})
    );

    // ==========================================
    // STAGE 5: WRITEBACK (W)
    // ==========================================
    
    // --- CSR MODIFICATION: Instantiation ---
    wire [31:0] CSR_ReadData_W;

    CSR_File CSR_UNIT (
        .clk(clk),
        .rst_n(!rst), // Assuming active low reset
        
        // Write Port (WB Stage)
        .wb_csr_addr(CSR_Addr_W),
        .wb_csr_wdata(CSR_WriteData_W),
        .wb_csr_write_en(CSRWrite_W),
        
        // Read Port (We read in WB for simple CSR instructions, or pipeline logic)
        .csr_addr(CSR_Addr_W), 
        .csr_rdata(CSR_ReadData_W),
        
        // Direct Outputs (For Traps)
        .mepc_out(CSR_mepc),
        .mtvec_out(CSR_mtvec)
    );

    // Mux to select Result: ALU vs Memory vs CSR
    // Note: We need a signal "IsCSR" to select CSR data. 
    // Ideally pass "ResultSrc" (2 bits) down pipeline instead of just MemtoReg.
    // For now, simple modification:
    
    assign Result_W = (MemtoReg_W) ? ReadData_W : 
                      (CSRWrite_W) ? CSR_ReadData_W : // Simple hack: if writing CSR, we also read old val
                      ALUResult_W;

    assign RegWriteAddr_W = rd_W;   
    assign RegWriteData_W = Result_W; 

    // Trap Logic (Placeholder)
    assign Trap_Take = 1'b0; // Connect this to Exception logic later!

endmodule