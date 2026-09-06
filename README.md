# RISC-V + Custom FIR DSP Hardware Accelerator on Tang Nano 20K

A hardware/software co-designed DSP system that integrates a **PicoRV32 RISC-V RV32I processor** with a custom **8-tap FIR (Finite Impulse Response) hardware accelerator**, deployed on the **Sipeed Tang Nano 20K FPGA**.

The RISC-V processor configures the accelerator through a memory-mapped interface, starts the FIR computation, waits for completion, and reads back the hardware-generated result.

---

## Project Overview

This project demonstrates how a custom DSP accelerator can be integrated into a RISC-V-based SoC to offload computationally intensive signal-processing operations from the processor.

### Core idea

```text
                    ┌──────────────────────────┐
                    │       PicoRV32 CPU       │
                    │       RISC-V RV32I       │
                    └────────────┬─────────────┘
                                 │
                          Memory-Mapped I/O
                                 │
                    ┌────────────▼─────────────┐
                    │     FIR MMIO Interface    │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │   8-Tap FIR Accelerator  │
                    │                           │
                    │  16-bit Samples           │
                    │  16-bit Coefficients      │
                    │  16×16 Multiplication     │
                    │  40-bit Accumulation      │
                    └────────────┬─────────────┘
                                 │
                           FIR Result
                                 │
                    ┌────────────▼─────────────┐
                    │       UART / Firmware     │
                    └──────────────────────────┘