# 32-Bit RISC-V Pipelined Processor

## Project Overview
This project implements a fully synthesized **5-Stage Pipelined Processor** based on the RISC-V 32-bit Integer (RV32I) instruction set architecture. It is designed using Verilog HDL and features a hardware-based **Data Forwarding Unit** to resolve execution hazards without software stalls.

## Key Features
* **5-Stage Pipeline:** Implements Fetch (IF), Decode (ID), Execute (EX), Memory (MEM), and Writeback (WB) stages to maximize instruction throughput.
* **Hazard Mitigation:** Contains a dedicated **Forwarding Unit** that detects Read-After-Write (RAW) data dependencies and bypasses the Register File, forwarding ALU results directly from Memory/Writeback stages.
* **Generic Pipeline Registers:** Modular design allowing for easy expansion of pipeline width.
* **Verified Functionality:** Validated using a custom Assembly BCD (Binary Coded Decimal) addition algorithm to test arithmetic, branching, and memory operations.

## Architecture
* **Top Level:** `riscv_pipeline_top.v`
* **Hazard Handling:** `riscv_forwarding.v` (Resolves ALU dependencies)
* **Control Unit:** Decodes Opcode/Funct3/Funct7 to generate control signals.
* **ALU:** Handles Arithmetic (ADD, SUB) and Logic (AND, OR, SLT) operations.

## Simulation
The design was simulated using Icarus Verilog and GTKWave.
(./docs/bcd_test_pipeline_processor.png)<img width="1355" height="542" alt="bcd_test_pipeline_processor" src="https://github.com/user-attachments/assets/fd76deb8-d3f1-4441-a71b-3c76a6494333" />

* **Testbench:** `cpu_pipe_tb.v` runs a full program cycle verifying the Data Forwarding logic.
