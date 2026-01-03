module riscv_imm_gen (
    input  wire [31:0] inst,
    output reg  [31:0] imm_out
);

    wire [6:0] opcode = inst[6:0];

    always @(*) begin
        case (opcode)
            // I-Type (ADDI, LW, JALR, etc.)
            7'b0010011, 7'b0000011, 7'b1100111, 7'b1110011: 
                // Force Sign Extension for 12-bit Immediate
                imm_out = { {20{inst[31]}}, inst[31:20] };

            // S-Type (SW)
            7'b0100011: 
                imm_out = { {20{inst[31]}}, inst[31:25], inst[11:7] };

            // B-Type (BEQ, BNE, etc.)
            7'b1100011: 
                imm_out = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };

            // J-Type (JAL)
            7'b1101111: 
                imm_out = { {12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0 };

            // U-Type (LUI, AUIPC) - THE CRITICAL PART
            // Just zero-fill the bottom 12 bits. No sign extension needed.
            7'b0110111, 7'b0010111: 
                imm_out = { inst[31:12], 12'b0 };

            default: imm_out = 32'b0;
        endcase
    end
endmodule