module riscv_imem (
    input wire [31:0] a,
    output wire [31:0] rd
);
    reg [31:0] RAM [63:0];
    // ... inside your riscv_imem module ...
    // ... inside riscv_imem.v ...
    initial begin
        // --- SETUP SECTION ---
        RAM[0] = 32'h40000113; // ADDI sp, x0, 1024
        RAM[1] = 32'h80000437; // LUI s0, 0x80000
        
        // [FIX] Load the Reference Value (x5) EARLY
        RAM[2] = 32'h000202b7; // LUI x5, 0x20000 (Target = 131072)

        // --- PRINT "V" ---
        RAM[3] = 32'h05600513; // Load 'V'
        RAM[4] = 32'h00a42023; // Print 'V'

        // --- PRINT "J" ---
        RAM[5] = 32'h04a00513; // Load 'J'
        RAM[6] = 32'h00a42023; // Print 'J'

        // --- CUSTOM MATH ---
        RAM[7] = 32'h000200b7; // LUI x1, 0x20000
        RAM[8] = 32'hfff08093; // ADDI x1, -1
        RAM[9] = 32'h00010137; // LUI x2, 0x10000
        RAM[10] = 32'h00110113; // ADDI x2, 1
        
        // EXECUTE ACCELERATOR
        RAM[11] = 32'h0020918b; // custom.vadd x3, x1, x2

        // --- CHECK RESULT ---
        // x5 has been ready for 10 cycles now. No hazard possible.
        RAM[12] = 32'h00518663; // BEQ x3, x5, +12 (Success)

        // --- FAIL PATH ---
        RAM[13] = 32'h04600513; // Load 'F'
        RAM[14] = 32'h00a42023; // Print 'F'
        RAM[15] = 32'h0080006f; // Jump End

        // --- SUCCESS PATH ---
        RAM[16] = 32'h05300513; // Load 'S'
        RAM[17] = 32'h00a42023; // Print 'S'

        // --- LOOP ---
        RAM[18] = 32'h0000006f; 
    end
    assign rd = RAM[a[31:2]]; 
endmodule