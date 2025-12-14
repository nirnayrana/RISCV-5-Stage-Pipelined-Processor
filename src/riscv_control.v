module riscv_control (
    input wire [6:0] opcode,
    output reg Branch,      // Capitalized to match Top Level
    output reg MemRead,
    output reg MemtoReg,
    output reg [1:0] ALUOp,
    output reg MemWrite,
    output reg ALUSrc,
    output reg RegWrite
);
    always @(*) begin
        {Branch, MemRead, MemtoReg, ALUOp, MemWrite, ALUSrc, RegWrite} = 0;
        
        case(opcode)
            7'b0110011: begin // R-Type (ADD)
                RegWrite = 1; ALUOp = 2'b10; 
            end
            7'b0010011: begin // I-Type (ADDI)
                RegWrite = 1; ALUSrc = 1; ALUOp = 2'b00;
            end
            7'b0000011: begin // LW
                RegWrite = 1; ALUSrc = 1; MemtoReg = 1; MemRead = 1;
            end
            7'b0100011: begin // SW
                ALUSrc = 1; MemWrite = 1;
            end
            7'b1100011: begin // BEQ
                Branch = 1; ALUOp = 2'b01;
            end
        endcase
    end
endmodule