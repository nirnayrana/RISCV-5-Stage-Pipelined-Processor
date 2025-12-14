module riscv_imm_gen (
    input wire [31:0] inst,  // Matches "inst" in top level
    output reg [31:0] imm_out
);
    always @(*) begin
        // I-Type (ADDI, LW, JALR)
        if (inst[6:0] == 7'b0010011 || inst[6:0] == 7'b0000011 || inst[6:0] == 7'b1100111) 
            imm_out = {{20{inst[31]}}, inst[31:20]};
        // S-Type (SW)
        else if (inst[6:0] == 7'b0100011) 
            imm_out = {{20{inst[31]}}, inst[31:25], inst[11:7]};
        // B-Type (BEQ)
        else if (inst[6:0] == 7'b1100011) 
            imm_out = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
        else
            imm_out = 32'b0;
    end
endmodule