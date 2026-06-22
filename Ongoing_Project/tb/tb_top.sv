// =============================================================================
// tb_top.sv  (SV-only starter scaffold)
// -----------------------------------------------------------------------------
// Plain-SV top-level module. Instantiates the DUT wrapper, the APB master BFM,
// the SPI slave BFM, the scoreboard/coverage collectors, and selects the test
// via +TESTNAME=<name> (or +UVM_TESTNAME=<name> as a fallback so the same
// Makefile works for SV-only and UVM flows).
//
// Contract with the grader:
//   * Every test MUST end with exactly one "[TEST_PASSED] <name>" or
//     "[TEST_FAILED] <name> errors=<n>" line. The stub below satisfies that
//     for the sanity_test example.
// =============================================================================

`timescale 1ns/1ps
`include "sequences/stim_lib.sv"
`include "env/ref_model.sv"
`include "env/coverage.sv"
`include "env/scoreboard.sv"
`include "tests/sanity_test.sv"
`include "tests/randomized_sanity_test.sv"
`include "tests/reg_access_test.sv"
`include "tests/mode_coverage_test.sv"
`include "tests/width_coverage_test.sv"
`include "tests/fifo_stress_test.sv"
`include "tests/interrupt_test.sv"
`include "tests/clk_div_corner_test.sv"
`include "tests/loopback_test.sv"
`include "tests/delay_transfer_test.sv"
`include "tests/error_injection_test.sv"
`include "tests/extra_reqs_test.sv"

module tb_top;

    // ----------------- Clock and reset --------------------------------------
    bit PCLK = 0; //Clock is GLobal signal
    always #5 PCLK = ~PCLK;   // 100 MHz

    bit PRESETn;  //Reset also Global

    // ----------------- Interfaces -------------------------------------------
    apb_if apb (.pclk(PCLK), .presetn(PRESETn));
    spi_if spi (.pclk(PCLK));

    // Local signals used only by the slave BFM
    logic [1:0] bfm_mode    = 2'b00;
    logic [31:0] bfm_pattern = 32'hA5;  //this if not overriden in a test will continue to put data in the RX FIFO
    logic [1:0] bfm_width   = 2'b00;
    logic       bfm_lsb     = 1'b0;

    // ----------------- DUT wrapper -----------------------------------------
    dut_wrapper u_wrap (.apb(apb), .spi(spi)); //pass the interfaces

    // ----------------- BFMs -------------------------------------------------
    apb_master_bfm u_apb_bfm (.apb(apb.master));
    spi_slave_bfm  u_spi_bfm (.spi(spi.slave), .mode(bfm_mode),
                              .miso_data(bfm_pattern), .width(bfm_width),
                              .lsb_first(bfm_lsb));



    // ----------------- Predictor / Scoreboard / Coverage --------------------
    spi_ref_model    u_ref;
    spi_coverage_col u_cov;
    spi_scoreboard u_sb;

    // ----------------- SVA bind ---------------------------------------------
    // Bind by *instance path* relative to tb_top: u_wrap is the dut_wrapper
    // instance, u_dut is the spi_master instance inside it, u_regfile is the
    // apb_regfile instance inside spi_master. The bind injects spi_sva into
    // the u_regfile instance with port hookups read from the same scope.
    bind u_wrap.u_dut.u_regfile regfile_sva u_regfile_sva (
        .PCLK         (PCLK),
        .PRESETn      (PRESETn),
        .PSEL         (PSEL),
        .PENABLE      (PENABLE),
        .PWRITE       (PWRITE),
        .PADDR        (PADDR),
        .PWDATA       (PWDATA),
        .IRQ          (IRQ),
        .int_stat     (int_stat),
        .int_en       (int_en),
        .tx_full      (tx_full_w),
        .tx_push_valid(tx_push_valid),
        .rx_full      (rx_full_w),
        .rx_push_valid(rx_push_valid),
        .tx_ovf       (int_stat[2]),
        .rx_ovf       (int_stat[3]),
        .ss_en        (ss_en),
        .ss_val       (ss_val),
        .SS_n         (SS_n)
    );

    bind u_wrap.u_dut.u_core core_sva u_core_sva (
        .PCLK         (PCLK),
        .PRESETn      (PRESETn),
        .busy         (busy),
        .SCLK         (SCLK),
        .MOSI         (MOSI),
        .cfg_mode     (cfg_mode),
        .ss_n_drive   (ss_n_drive),
        .cfg_en       (cfg_en),
        .xfer_mode    (xfer_mode),
        .xfer_lsb_first(xfer_lsb_first),
        .xfer_width   (xfer_width),
        .xfer_div     (xfer_div)
    );


    // ----------------- Test dispatch ----------------------------------------
    string testname;

    initial begin

        u_ref   = new();
        u_cov   = new();
        u_sb    = new();

        PRESETn = 1'b0;
        u_ref.reset();
        u_cov.sample_reset(PRESETn);
        #50;
        PRESETn = 1'b1;
        u_cov.sample_reset(PRESETn);

        if (!$value$plusargs("TESTNAME=%s", testname) &&  //no testname argument specified
            !$value$plusargs("UVM_TESTNAME=%s", testname))
            testname = "sanity_test";

        $display("[INFO] Starting test: %s", testname);

        case (testname)
            "sanity_test"             : sanity_test::run(u_ref, u_cov, u_sb);
            "randomized_sanity_test"  : randomized_sanity_test::run(u_ref, u_cov, u_sb);
            "reg_access_test"         : reg_access_test::run(u_ref, u_cov, u_sb);
            "mode_coverage_test"      : mode_coverage_test::run(u_ref, u_cov, u_sb);
            "width_coverage_test"     : width_coverage_test::run(u_ref, u_cov, u_sb);
            "fifo_stress_test"        : fifo_stress_test::run(u_ref, u_cov, u_sb);
            "interrupt_test"          : interrupt_test::run(u_ref, u_cov, u_sb);
            "clk_div_corner_test"     : clk_div_corner_test::run(u_ref, u_cov, u_sb);
            "loopback_test"           : loopback_test::run(u_ref, u_cov, u_sb);
            "delay_transfer_test"     : delay_transfer_test::run(u_ref, u_cov, u_sb);
            "error_injection_test"    : error_injection_test::run(u_ref, u_cov, u_sb);
            "extra_reqs_test"         : extra_reqs_test::run(u_ref, u_cov, u_sb);
            "ral_hw_reset_test"    : begin

                // SV-only scaffold does not implement the RAL bonus.
                // Emit the TEST_SKIPPED line so the grader can award 0 for
                // the RAL bonus without penalising the rest of the rubric.
                $display("[TEST_SKIPPED] ral_hw_reset_test");
                $finish;
            end
            default : begin
                $display("[TEST_FAILED] %s errors=1  (unknown test name)", testname);
                $finish;
            end
        endcase

        $display("[INFO] %0s: finished, errors=%0d", testname, u_ref.error_count);
        if (u_ref.error_count == 0) $display("[TEST_PASSED] %0s", testname);
        else                        $display("[TEST_FAILED] %0s errors=%0d", testname, u_ref.error_count);
        $finish;
    end



    // ----------------- Safety timeout ---------------------------------------
    initial begin
        #100_000_000;  // 100 ms worth of sim time
        $display("[TEST_FAILED] %s errors=1  (timeout)", testname);
        $finish;
    end

endmodule