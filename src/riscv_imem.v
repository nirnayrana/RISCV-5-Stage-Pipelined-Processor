module riscv_imem (
    input wire [31:0] a,
    output wire [31:0] rd
);
    reg [31:0] RAM [63:0];
    initial begin
        RAM[0] = 32'h00500093; // ADDI x1, x0, 5
        RAM[1] = 32'h00800113; // ADDI x2, x0, 8
        RAM[2] = 32'h002081b3; // ADD x3, x1, x2  (Now x1=5, x2=8 are ready!)
        RAM[3] = 32'h00900213; // ADDI x4, x0, 9 
        RAM[4] = 32'h003222b3; // SLT x5, x4, x3
        RAM[5] = 32'h00028463; // BEQ x5, x0, +8
        RAM[6] = 32'h00600313; // ADDI x6, x0, 6
        RAM[7] = 32'h006181b3; // ADD x3, x3, x6
        RAM[8] = 32'h00000000; // STOP
    end
    assign rd = RAM[a[31:2]]; 
endmodule