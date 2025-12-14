`timescale 1ns/1ns
module cpu_tb_final;
    reg clk, rst;
    reg [30*8:1] status_msg; 
    riscv_pipeline_top uut ( .clk(clk), .rst(rst) );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    initial begin
        $dumpfile("cpu_final.vcd");
        $dumpvars(0, cpu_tb_final);
        $display("=================================================================================================");
        $display(" TIME | PC | INSTR    | PHASE               | x1(10)| x2(20)| x3(30)| x4(30)| x5(Success?)");
        $display("=================================================================================================");
        $monitor("  %0t  | %d | %h | %-19s |   %d   |   %d   |   %d   |   %d   |      %d", $time, uut.PC_F, uut.Instr_F,     // Updated Name
         status_msg,
         uut.REG_FILE.rf[1], 
         uut.REG_FILE.rf[2], 
         uut.REG_FILE.rf[3], 
         uut.REG_FILE.rf[4], 
         uut.REG_FILE.rf[5]
);
        status_msg = "RESET";
        rst = 1; #10;
        rst = 0;
        status_msg = "INIT VALUES"; 
        #20; 
        status_msg = "CALCULATING (10+20)";
        #10;
        status_msg = "SAVING TO RAM";
        #10;
        status_msg = "READING FROM RAM";
        #10;
        status_msg = "DECIDING (Is Eq?)";
        #10;    
        status_msg = "JUMPING...";
        #10;
        status_msg = "MISSION COMPLETE";
        #500;
        $finish;
    end
endmodule