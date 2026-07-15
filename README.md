# SPI Master Verification Project

## Project Overview

This project was developed as the final project for a **Digital Design Verification course**. Its purpose is not to design the SPI controller itself, but to build a complete and reusable verification environment around an existing RTL implementation.

The verification environment is first developed and validated against a trusted **golden RTL** implementation. Once the environment is proven to operate correctly, the golden design can be replaced by modified RTL versions containing seeded bugs. The quality of the environment is then evaluated by how many of those bugs it detects through scoreboarding, assertions, protocol checks, and coverage-driven tests.

This approach reflects a real verification workflow: understand the specification, create an independent checking environment, establish confidence using a known-good design, and then test whether the environment can expose realistic implementation faults.

---

## Design Under Verification

The DUT is an **APB-controlled SPI Master Controller**.

Software communicates with the block through a 32-bit APB interface to configure the SPI operation, write transmit data, read received data, and manage status and interrupts.

The design is divided into two main RTL blocks:

- **APB register file:** handles APB accesses, configuration registers, TX/RX FIFOs, status flags, slave-select control, and interrupt generation.
- **SPI core:** performs serial transfers, generates SCLK, shifts MOSI/MISO data, applies the selected SPI mode and bit order, and inserts programmable delays.

The controller supports:

- All four SPI modes through CPOL and CPHA.
- 8-, 16-, and 32-bit transfers.
- MSB-first and LSB-first transmission.
- Four active-low slave-select outputs.
- Separate 8-entry TX and RX FIFOs.
- A programmable SPI clock divider.
- Programmable delays between consecutive transfers.
- Internal loopback operation.
- Maskable and sticky interrupt sources.

During a transfer, a word is taken from the TX FIFO and shifted through MOSI while MISO is sampled into the receive word. The received result is then pushed into the RX FIFO, status and interrupt information is updated, and another queued transfer may begin after the configured delay.

---

## Verification Objective

The main objective was to create a **self-checking SystemVerilog verification environment** that combines the key fundamentals introduced during the course:

- Directed and constrained-random stimulus.
- Bus and protocol BFMs.
- An independent reference model.
- Scoreboarding and explicit checkers.
- SystemVerilog Assertions.
- Functional coverage.
- RTL code coverage.
- Reusable tests and regression execution.
- Automated compilation, simulation, and report generation.

The environment is intentionally independent of a specific DUT implementation. The RTL source list can be replaced without editing the testbench, allowing the same verification environment to run against either the golden design or a buggy variant.

---

## Verification Environment

The project uses a plain SystemVerilog, non-UVM architecture.

```text
Tests and randomized transactions
                |
                v
       APB Master BFM
                |
                v
      SPI Master DUT <------> SPI Slave BFM
                |
        observed results
                |
       +--------+---------+
       |                  |
Reference Model       Assertions
       |
   Scoreboard
       |
Pass/fail messages and coverage
```

The top-level testbench creates the clock and reset, instantiates the DUT wrapper and interfaces, constructs the reference model, scoreboard, and coverage collector, binds the assertions, and dispatches the requested test using a simulation plusarg.

---

## Verification Fundamentals Applied

### 1. Stimulus Generation

The environment includes both directed tests and a reusable randomizable `spi_txn` transaction.

The transaction can randomize:

- SPI mode.
- Transfer width.
- Bit order.
- Clock-divider value.
- Inter-transfer delay.
- Transmit data.
- Loopback selection.

Directed tests are used for precise corner cases, while randomized stimulus explores combinations that may not be reached by a small set of manually selected values.

### 2. APB and SPI BFMs

The **APB master BFM** provides reusable read and write tasks that generate the APB setup and access phases and wait for the DUT response.

The **SPI slave BFM** models the external slave device. It reacts to slave-select and SCLK, drives MISO according to the selected mode, width, and bit order, and allows the tests to control the returned data pattern.

These BFMs separate low-level signal driving from the test intent, making the tests shorter and easier to reuse.

### 3. Reference Model

The reference model maintains an independent representation of the expected DUT state, including:

- Register contents.
- TX and RX FIFO contents.
- FIFO status.
- Interrupt status.
- Expected received words.

It predicts the result of each transfer from the active configuration, transmitted data, selected width, loopback setting, and SPI-slave response.

Because the prediction is produced independently from the DUT outputs, it can expose incorrect RTL behavior rather than simply repeating the implementation.

### 4. Scoreboard and Checkers

The scoreboard compares observed DUT behavior with the expected values produced by the reference model.

It checks items such as:

- Received SPI data.
- Register readback values.
- Reset values.
- FIFO behavior.
- Reserved-address behavior.

A mismatch is reported as a scoreboard or checker error and contributes to the final test result. This provides automatic pass/fail evaluation without requiring manual waveform inspection.

### 5. SystemVerilog Assertions

Assertions are bound into the APB register-file and SPI-core instances without modifying the RTL.

They check important temporal and protocol properties, including:

- APB `PSEL` duration.
- `PENABLE` only being asserted with `PSEL`.
- APB address, control, and data stability.
- TX and RX overflow behavior.
- Correct interrupt masking:
  `IRQ == |(INT_STAT & INT_EN)`.
- Correct slave-select output logic.
- SCLK returning to the CPOL idle level.
- MOSI stability at the sampling edge.
- Slave-select stability during a transfer.
- Configuration stability while the transfer is active.
- Clock-divider timing.
- Disabled-state behavior.

Assertions provide continuous checking during every test and can catch bugs even when a test does not explicitly read the affected state.

### 6. Functional Coverage

Functional coverage was written around the design specification rather than the RTL structure.

The covergroups measure scenarios such as:

- All four SPI modes.
- 8-, 16-, and 32-bit widths.
- MSB-first and LSB-first operation.
- Mode × width × bit-order combinations.
- Loopback enabled and disabled.
- Important clock-divider values.
- Delay values.
- TX and RX FIFO occupancy.
- Interrupt events, masks, and clearing.
- Reads and writes to all valid and reserved register addresses.
- Register reset values.

Functional coverage shows which required behaviors have been exercised and helps guide additional stimulus toward missing scenarios.

### 7. Code and Assertion Coverage

The DUT is compiled with simulator coverage instrumentation.

The generated reports include:

- Functional coverage.
- Assertion and cover-property coverage.
- RTL statement coverage.
- Branch and expression coverage.
- FSM and toggle coverage.

Code coverage is used as a structural complement to functional coverage. Functional coverage answers whether the planned scenarios were tested, while code coverage helps reveal RTL logic that the tests did not execute.

### 8. Test and Regression Structure

The regression contains focused tests for:

- Basic transfers and loopback.
- Randomized sanity scenarios.
- Register access and reset values.
- All SPI modes.
- All supported transfer widths.
- FIFO full, empty, and overflow conditions.
- Interrupt generation, masking, and W1C behavior.
- Clock-divider corner values.
- Inter-transfer delay behavior.
- Reserved and illegal accesses.
- Additional specification requirements.

Using smaller focused tests makes failures easier to diagnose while the complete regression provides broader confidence.

---

## Golden RTL and Bug Detection

The environment is initially run against the golden RTL to confirm that:

- Legal tests pass.
- Checkers do not produce false failures.
- Assertions are correctly written.
- Functional and code coverage reach the intended scenarios.
- The regression runs reliably and repeatedly.

After that, the RTL source list can be replaced with a buggy DUT while the same testbench remains unchanged.

A seeded bug is considered caught when the environment produces an assertion failure, scoreboard mismatch, checker error, or another clear simulation error. The project is therefore evaluated mainly by the **strength and completeness of the verification environment**, not by knowledge of the injected bugs.

---

## Makefile Automation

The Makefile automates the complete simulation workflow. It manages source compilation, test selection, regression execution, coverage collection, report generation, and cleanup.

### Compile the project

```bash
make compile
```

Compiles the interfaces, selected DUT sources, wrapper, BFMs, assertions, environment, and testbench.

### Run one test

```bash
make run TEST=sanity_test SEED=1
```

The `TEST` variable selects the test and `SEED` controls randomized stimulus.

To save a waveform:

```bash
make run TEST=mode_coverage_test SEED=7 WAVES=1
```

### Run the regression

```bash
make regress
```

Runs the complete test list and merges the generated coverage databases.

### Generate the coverage report

```bash
make cov
```

Creates `coverage_report.txt` containing functional, assertion, and DUT code-coverage results.

### Clean generated files

```bash
make clean
```

Removes compiled libraries, logs, waveform files, coverage databases, and generated reports.

### Run against another DUT

The same environment can be applied to different RTL versions by overriding `DUT_SRCS`:

```bash
make compile DUT_SRCS="path/to/spi_core.sv path/to/apb_regfile.sv path/to/spi_master.sv"
make regress DUT_SRCS="path/to/spi_core.sv path/to/apb_regfile.sv path/to/spi_master.sv"
make cov
```

This source-override mechanism is what allows the golden RTL to be replaced by a buggy implementation without changing the tests or checkers.

---

## Project Structure

```text
Ongoing_Project/
├── assertions/       # Bound SystemVerilog assertions
├── env/              # Reference model, scoreboard, and coverage
├── golden_rtl/       # Trusted RTL used to validate the environment
├── harness/          # Interfaces and DUT wrapper
├── sequences/        # Reusable randomizable transactions
├── tb/               # Top-level testbench and BFMs
├── tests/            # Directed and randomized tests
├── docs/             # Test plan, final report, and coverage report
├── Makefile           # Automated simulation and coverage flow
└── README.md
```

---

## Possible Improvements

The environment can be extended further by:

- Increasing constrained-random testing across long transfer sequences.
- Expanding the reference model to predict every status transition cycle-by-cycle.
- Adding more cross coverage for interrupt events, masks, FIFO state, and active configuration.
- Adding assertions for exact transfer length, BUSY timing, FIFO ordering, and delay timing.
- Running a larger multi-seed regression within the available runtime budget.
- Introducing automated coverage closure and bug-based regression ranking.
- Migrating the structure to UVM for greater reuse and scalability in larger projects.
