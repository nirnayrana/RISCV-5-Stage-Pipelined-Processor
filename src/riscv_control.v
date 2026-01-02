module riscv_control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,  // Added funct3 (Needed to distinguish CSRRW vs MRET)
    
    // Standard Controls
    output reg       Branch,
    output reg       MemRead,
    output reg       MemtoReg,
    output reg [1:0] ALUOp,
    output reg       MemWrite,
    output reg       ALUSrc,
    output reg       RegWrite,
    output reg IllegalInst,
    
    // --- NEW CSR CONTROLS ---
    output reg       CSRWrite, // Enables writing to CSR File
    output reg       CSRRead,  // Enables reading (affects Result Mux)
    output reg       IsMRET    // Tells PC to jump to EPC
);

    always @(*) begin
        // Defaults (Safety First)
        Branch   = 0;
        MemRead  = 0;
        MemtoReg = 0;
        ALUOp    = 2'b00;
        MemWrite = 0;
        ALUSrc   = 0;
        RegWrite = 0;
        CSRWrite = 0;
        CSRRead  = 0;
        IsMRET   = 0;
        IllegalInst=0;

        case (opcode)
            // ... (Your existing cases for R-Type, I-Type, Load, Store, Branch) ...
            
            // R-Type (add, sub, etc.)
            7'b0110011: begin 
                RegWrite = 1; 
                ALUOp = 2'b10; 
            end

            // I-Type (addi, etc.)
            7'b0010011: begin 
                ALUSrc = 1; 
                RegWrite = 1; 
                ALUOp = 2'b10; // Use funct3 to determine operation
            end

            // Load (lw)
            7'b0000011: begin 
                ALUSrc = 1; 
                MemtoReg = 1; 
                RegWrite = 1; 
                MemRead = 1; 
            end

            // Store (sw)
            7'b0100011: begin 
                ALUSrc = 1; 
                MemWrite = 1; 
            end

            // Branch (beq)
            7'b1100011: begin 
                Branch = 1; 
                ALUOp = 2'b01; 
            end

            // --- THE NEW PART: SYSTEM INSTRUCTIONS --
            7'b0110111: begin
                RegWrite = 1;
                ALUSrc   = 1;  // Use Immediate
                ALUOp    = 2'b11; // You need to ensure ALU handles this or just pass Imm
                // Note: Standard ALU might need specific ALUOp for LUI. 
                // A cheat for LUI: It's just "Imm + 0" if Imm is shifted.
                // Or simply:
                MemtoReg = 0;
            end
            7'b1110011: begin
                // Check for valid funct3
                if (funct3 != 3'b000 && funct3 != 3'b001 && funct3 != 3'b010) 
                    IllegalInst = 1; // Mark unknown system ops as illegal
                
                // ... rest of logic ...
            end

            // --- THE CATCH-ALL ---
            default: begin
                IllegalInst = 1; // If opcode is unknown, it's ILLEGAL!
                RegWrite = 0;    // Don't let it corrupt registers
                MemWrite = 0;    // Don't let it corrupt memory
            end
        endcase
    end
endmodule