module riscv_imem (
    input wire [31:0] a,
    output wire [31:0] rd
);
    reg [31:0] RAM [63:0];
    // ... inside your riscv_imem module ...
    // ... inside riscv_imem.v ...
    initial begin
        // 1. Load IO Address (0x80000000) into x1
        // LUI x1, 0x80000
        RAM[0] = 32'h800000B7; 

        // 2. Load 'V' (0x56) into x2
        // ADDI x2, x0, 0x56
        RAM[1] = 32'h05600113;

        // 3. Print 'V' (Store Word x2 into address at x1)
        // SW x2, 0(x1) -> Writes 0x56 to 0x80000000
        RAM[2] = 32'h0020A023;

        // 4. Load 'A' (0x41) into x2
        RAM[3] = 32'h04100113;

        // 5. Print 'A'
        RAM[4] = 32'h0020A023;

        // 6. Loop forever
        RAM[5] = 32'h00000063;
    end
    assign rd = RAM[a[31:2]]; 
endmodule