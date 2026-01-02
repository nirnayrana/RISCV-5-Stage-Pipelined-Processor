module riscv_imem (
    input wire [31:0] a,
    output wire [31:0] rd
);
    reg [31:0] RAM [63:0];
    // ... inside your riscv_imem module ...
    initial begin
        // --- INITIALIZATION ---
        // 0. Set MTVEC (The Hospital Address) to 20 (0x14)
        // PC=0: ADDI x1, x0, 20
        RAM[0] = 32'h01400093; 
        
        // PC=4: CSRRW x0, mtvec, x1 (Write 20 to mtvec)
        RAM[1] = 32'h30509073; 

        // 1. A Normal Instruction (Verification that we started ok)
        // PC=8: ADDI x2, x0, 15 (x2 = 15)
        RAM[2] = 32'h00F00113; 

        // --- THE CRASH EVENT ---
        // 2. THE ILLEGAL INSTRUCTION 
        // PC=12: 0xFFFFFFFF (Invalid Opcode). 
        // CPU should: Detect Illegal -> Save PC(12) to mepc -> Jump to mtvec(20).
        RAM[3] = 32'hFFFFFFFF; 

        // 3. The "Unreachable" Code (We should SKIP this)
        // PC=16: ADDI x3, x0, 7 (x3 SHOULD REMAIN 0)
        RAM[4] = 32'h00700193; 

        // --- TRAP HANDLER (Address 20 / 0x14) ---
        // 4. The "Hospital" Code (Success Indicator)
        // PC=20: ADDI x4, x0, 88 (0x58) -> "I AM ALIVE"
        RAM[5] = 32'h05800213; 
        
        // 5. Loop forever
        RAM[6] = 32'h00000063; 
        
        // Fill rest with NOPs
        RAM[7] = 32'h00000013;
        RAM[8] = 32'h00000013;
    end
    assign rd = RAM[a[31:2]]; 
endmodule