# Runtime Predictive Hybrid Floating Point Unit

This repository presents a **runtime-adaptive floating-point unit (FPU)** that dynamically selects between **exact FP32 arithmetic**, **approximate FP32 arithmetic**, and a **BF16 transprecision path** based on operand characteristics. The design is intended for **energy-efficient AI and signal processing workloads** where full IEEE-754 precision is not always required.

The architecture uses **predictive operand analysis** to decide the arithmetic mode before computation, ensuring that unnecessary hardware blocks are not activated, thereby achieving real power and area savings.

---

## Key Features
- Supports IEEE-754 single-precision (FP32) addition, subtraction, and multiplication
- Predictive runtime selection between:
  - Exact FP32
  - Approximate FP32
  - BF16 transprecision (optional path)
- Cancellation-aware and exponent-aware precision selection
- Operand isolation for real dynamic power reduction
- Fully synthesizable and ASIC-ready RTL

---

## Important Note on ASIC Flow
For the **ASIC implementation and synthesis flow**, only:
- **Exact FP32** and
- **Approximate FP32**

datapaths were enabled and used.

The **BF16 transprecision path** is included in the RTL for architectural completeness and future extensions, but **it was not used in the Cadence Genus synthesis, power, and timing analysis**.

---

## Tools Used
- RTL Simulation: Cadence Nclaunch (NC-Sim)
- Synthesis: Cadence Genus
- Technology Library: 90 nm standard-cell library
- Logical Equivalence Check: Cadence Conformal LEC
- Cadence Innovus: Physical Flow

---

## Summary
This project demonstrates how **predictive, operand-aware mixed-precision arithmetic** can significantly reduce power and area while maintaining correctness for error-tolerant workloads such as AI inference.

---

## License
For academic and research use.

---

## Author
SRI HARI A S
B.Tech Electronics and Communicaton
sriharias2204@gmail.com
