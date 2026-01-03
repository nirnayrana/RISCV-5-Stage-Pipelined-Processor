module riscv_regfile(
    input  wire       clk,
    input  wire       we3,           // Write Enable
    input  wire [4:0] ra1, ra2, wa3, // Read/Write Addresses
    input  wire [31:0] wd3,          // Write Data
    output wire [31:0] rd1, rd2      // Read Data
);

    reg [31:0] rf[31:0];

    // Initialize x0 to 0 (optional, for simulation)
    integer i;
    initial begin
        for (i=0; i<32; i=i+1) rf[i] = 0;
    end

    // WRITE LOGIC (Synchronous)
    always @(posedge clk) begin
        if (we3 && wa3 != 0) begin // Never write to x0
            rf[wa3] <= wd3;
        end
    end

    // READ LOGIC (Asynchronous with Internal Forwarding)
    // Fixes the WB-ID Hazard:
    assign rd1 = (ra1 == 0) ? 32'b0 :
                 (ra1 == wa3 && we3) ? wd3 : // <--- FORWARDING!
                 rf[ra1];

    assign rd2 = (ra2 == 0) ? 32'b0 :
                 (ra2 == wa3 && we3) ? wd3 : // <--- FORWARDING!
                 rf[ra2];

endmodule