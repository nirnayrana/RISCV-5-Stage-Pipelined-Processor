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
* ## 🚀 Latest Update: Privilege Levels & Exception Handling
**Date:** 2/1/2026

Moved the processor from a standard user-mode core to a **Privileged Architecture**.

### 🆕 New Features
* **CSR Unit (Control Status Registers):** Implemented `mstatus`, `mepc`, `mtvec`, and `mcause`.
* **Hardware Traps:** CPU now automatically detects `Illegal Instructions`, flushes the pipeline, and jumps to the Exception Handler.
* **Zicsr Support:** Added support for `CSRRW`, `CSRRS`, `MRET` instructions.

### 🐛 Bug Fixes
* **Pipeline Hazard:** Fixed a critical bug where the instruction in the `Fetch` stage would execute during a Trap.
    * *Solution:* Implemented synchronous `NOP` injection in the IF/ID pipeline register.
<<<<<<< HEAD
=======

### 📉 Verification
Running the "Crash Test" assembly program:
1.  CPU initializes vectors.
2.  Executes `0xFFFFFFFF` (Illegal Opcode).
3.  Traps to address `0x14`.
4.  Recovery code executes successfully (`x4 = 0x58`).
>>>>>>> 31a986688cdedbd17e01aee4fbb287443fd77936
## 🛡️ Major Release: VAJRA SoC (System-on-Chip)
**Status:** Industrial Robustness Achieved

The core has evolved from a simple CPU to a **Versatile SoC** designed for high-reliability applications.

### 🔧 Architecture Upgrades
* **Hazard-Free Pipeline:** Solved critical **Write-Back (WB-ID)** hazards using internal Register File forwarding.
* **Pipelined Control:** Opcode propagation added to ID/EX stages to prevent ALU control hazards during fast switching.
* **Smart Flushing:** Implemented **Selective Pipeline Flushing** to preserve valid instructions during exceptions.

### 🚀 New Capabilities
| Feature | Description | Implementation |
| :--- | :--- | :--- |
| **Custom Extensions** | Dedicated "Sidecar" Execution Unit for proprietary algorithms (Crypto/DSP). | `opcode: custom-0` |
| **Memory Mapped I/O** | Direct hardware communication via memory addresses. | `UART @ 0x80000000` |
| **Saturation Math** | Verified 16-bit Vector Addition with overflow handling. | **Verified** |

### 📟 Verification Logs
**Test 1: Custom Vector Addition (SIMD)**
> Input: `0x1FFFF` + `0x10001`
> Result: `0x20000` (Correctly handled split arithmetic)

**Test 2: UART "Hello World"**
> The processor successfully wrote ASCII `V` (0x56) and `A` (0x41) to the UART output port.
