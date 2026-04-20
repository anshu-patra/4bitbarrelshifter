# 4-Bit Barrel Shifter — Full Scan DFT & ATPG

> **Cadence Genus 20.11 + Modus 20.12 | 90nm Technology | Muxed-Scan | 100% Static Fault Coverage**

A complete RTL-to-ATPG implementation for a **pipelined 4-bit barrel shifter** using industry-standard EDA tools.

---
## Design Overview
![Design Overview Digram](schematic/block_digram.png)

`barrel_shifter_4bit` is a **2-stage pipelined left-rotate barrel shifter**. Rotation is decomposed across two registered pipeline stages, each clocked on the rising edge of `clk`. Pipeline latency is 2 clock cycles.

### Port List

| Port | Width | Dir | Description |
|------|-------|-----|-------------|
| `clk` | 1 | In | System clock (20 ns / 50 MHz) |
| `rst_n` | 1 | In | Active-low asynchronous reset |
| `data_in` | 4 | In | 4-bit data to rotate |
| `shift_amt` | 2 | In | Rotate amount: `00`=0, `01`=1, `10`=2, `11`=3 |
| `data_out` | 4 | Out | Rotated output (2-cycle latency) |
| `scan_en` | 1 | In | DFT: `1`=shift mode, `0`=capture mode |
| `scan_in` | 1 | In | Scan chain serial input |
| `scan_out` | 1 | Out | Scan chain serial output |

### Functional Truth Table

| `shift_amt` | Operation | Example (`data_in = 4'b1011`) |
|-------------|-----------|-------------------------------|
| `2'b00` | No rotate | `1011` |
| `2'b01` | Left rotate ×1 | `0111` |
| `2'b10` | Left rotate ×2 | `1110` |
| `2'b11` | Left rotate ×3 | `1101` |

---

## Tool Flow

![Tool Flow Digram](schematic/tool_flow.png)

See diagram below (or refer to `harshit_schm.png` for the post-DFT schematic).

**Stage 1 — Genus (Synthesis + DFT Insertion)**

RTL and SDC are read in, synthesized, and DFT rules are checked. Scan flip-flops replace standard FFs and are chained together. Outputs include the post-DFT netlist, scandef, pin assignment, and a Modus-ready script.

**Stage 2 — Modus (ATPG)**

The post-DFT netlist is modelled, scan chain structures are verified (all pass), the stuck-at fault model is built, and test vectors are generated. Result: 7 patterns covering 100% of 190 faults.

**Stage 3 — Xcelium (Gate-Level Simulation)**

Generated vectors are simulated both functionally and with SDF back-annotation for timing verification.

---

## DFT Implementation

**Scan Style: Muxed-Scan**

Each `SDFFRHQX1` flip-flop has a 2-to-1 mux at its D-input. When `scan_en = 1`, the FF captures serial scan data (shift mode). When `scan_en = 0`, it captures functional data (capture mode).

**Scan Chain (from `barrel_shifter_4bit_scan_chains.rpt`)**

Single chain `chain1`, 8 FFs in series from `scan_in` to `scan_out`:

```
scan_in → data_out_reg[0..3] → stage1_reg[0..3] → scan_out
```

Clock domain: `clk_test` (rising edge) | Shift enable: `scan_en` (active high)

**DFT Rule Check — from `barrel_shifter_4bit_post_dft_rules.rpt`**
 
```
Detected 0 DFT rule violation(s)
 
  Clock rule violations        : 0
  Async set/reset violations   : 0
  Total DFT violations         : 0
 
  Test clock domains           : 1  (clk_test, positive edge)
  Registers passing DFT rules  : 8 / 8
  Scannable register %         : 100%
```

**Pin Assignment**

| Port | Test Function | Role |
|------|--------------|------|
| `rst_n` | `+SC` | System Clock / Test Mode |
| `scan_en` | `+SE` | Scan Enable |
| `clk` | `-ES` | Edge-sensitive test clock |
| `scan_in` | `SI0` | Scan Input channel 0 |
| `scan_out` | `SO0` | Scan Output channel 0 |

---

## Synthesis Results (Genus 20.11, 90nm Slow Corner)

### Area

| Metric | Pre-DFT | Post-DFT | Change |
|--------|---------|---------|--------|
| Total cells | 8 | 16 | +8 |
| Cell area (µm²) | 200.578 | 260.374 | **+29.8%** |
| Sequential FFs | 8 | 8 | — |
| Logic (scan mux) | 0 | 8 | +8 |

**Pre-DFT — 8 cells (100% sequential)**

| Cell | Count | Area (µm²) |
|------|-------|-----------|
| `SDFFRHQX1` | 7 | 174.844 |
| `SDFFRHQX2` | 1 | 25.735 |
| **Total** | **8** | **200.578** |

**Post-DFT — 16 cells (8 scan muxes added)**

| Cell | Count | Area (µm²) | Type |
|------|-------|-----------|------|
| `SDFFRHQX1` | 8 | 199.822 | Sequential (Scan-FF) |
| `MX2XL` | 8 | 60.552 | Logic (scan mux) |
| **Total** | **16** | **260.374** | |

> In the pre-DFT netlist, `shift_amt[1:0]` directly drove the `SE` pins of FFs. After DFT insertion, `scan_en` takes over `SE` for test mode and dedicated `MX2XL` cells handle the functional mux logic — hence 8 new gates.

### Timing (Worst-Case Post-DFT Setup Path)

```
Path: stage1_reg[3]/CK → MX2XL(g229) → data_out_reg[1]/D

  Clock period   :  20,000 ps
  Required time  :  19,302 ps
  Data arrival   :     870 ps
  Slack          :  +18,433 ps  ✓ TIMING MET
```

### Power (Post-DFT)

| Category | Total (W) | % |
|----------|----------|---|
| Register | 12.471e-6 | 88.1% |
| Logic | 1.117e-6 | 7.9% |
| Clock | 5.670e-7 | 4.0% |
| **Total** | **14.155e-6** | |

Pre-DFT: 8.334 µW → Post-DFT: 14.155 µW (+70%, driven by 8 new `MX2XL` cells)

---

## ATPG Results (Modus 20.12 — FULLSCAN Mode)

### Scan Chain Verification — All Pass

| Check | Result |
|-------|--------|
| Chain controllable & observable (TSV-378) | ✓ PASS |
| Chain length = 100% of average (TSV-068) | ✓ PASS |
| Clock race analysis | ✓ PASS |
| Feedback loop analysis | ✓ PASS |
| TSD contention analysis | ✓ PASS |
| Clock chopper analysis | ✓ PASS |
| 1 controllable scan chain via SI (TSV-567) | ✓ PASS |
| 1 observable scan chain via SO (TSV-568) | ✓ PASS |

Active logic visibility: **95.21%** (4.79% inactive — tied constant nets on reset path)

### Fault Coverage

| Phase | Patterns | Faults Detected | Cumulative Coverage |
|-------|----------|----------------|-------------------|
| Scan | 1 | 72 | 37.89% |
| Reset/Set | 1 | 9 | 42.63% |
| Static Logic | 5 | 109 | 99.99% |
| **Total** | **7** | **190** | **100%** |

**Final Fault Statistics**

| Fault Model | Total | Tested | Coverage |
|-------------|-------|--------|---------|
| Total Static (SAF) | 190 | **190** | **100%** |
| Collapsed Static | 174 | 174 | **100%** |
| Total Dynamic | 154 | 54 | 35.1% |

Only **7 test vectors** achieve complete stuck-at (SAF) coverage across all 190 fault sites.

---

## How to Run

**Prerequisites**

| Tool | Version |
|------|---------|
| Cadence Genus | >= 20.11 |
| Cadence Modus | >= 20.12 |
| Cadence Xcelium | any |
| 90nm foundry library | `/home/install/FOUNDRY/digital/90nm/` |

**Step 1 — Synthesis + DFT Insertion (Genus)**

```bash
cd HARshit_0027/assignment/
genus -legacy_ui -f run_genus_dft.tcl | tee genus.log
```

**Step 2 — ATPG (Modus)**

```bash
modus -file runmodus.atpg.tcl | tee modus.log
# or: modus -f run_modus_atpg.tcl | tee modus.log
```

**Step 3 — Gate-Level Simulation (Optional)**

```bash
./run_fullscan_sim          # functional
./run_fullscan_sim_sdf      # with SDF timing back-annotation
```

---

## Post-DFT Schematic

![Post-DFT Schematic](schematic/harshit_schm.png)

The schematic shows 8 `SDFFRHQX1` scan flip-flops stitched serially from `scan_in` to `scan_out`, and 8 `MX2XL` cells implementing both the functional barrel-shift mux and the scan-enable mux path.

---

## Results Summary

| Metric | Value |
|--------|-------|
| Design | 4-bit pipelined barrel shifter (left rotate) |
| Technology | 90nm, slow corner |
| Synthesis tool | Cadence Genus 20.11 |
| ATPG tool | Cadence Modus 20.12 |
| Clock | 50 MHz (20 ns period) |
| DFT style | Muxed-Scan |
| Scan-FF cell | `SDFFRHQX1` |
| Total cells post-DFT | 16 (8 FF + 8 MUX) |
| Total area post-DFT | 260.374 µm² |
| DFT area overhead | +29.8% |
| Critical path slack | +18,433 ps — TIMING MET |
| DFT rule violations | **0** |
| Scan chains | 1 |
| Chain length | 8 FFs |
| Scannable FFs | 8 / 8 = **100%** |
| Stuck-at fault coverage | **100%** (190 / 190) |
| ATPG test patterns | **7** |
| Verify structures | **All PASS** |

---

## Author

**Anshu Patra** | IIIT Kurnool 

VLSI Design — DFT & ATPG  | April 2026
