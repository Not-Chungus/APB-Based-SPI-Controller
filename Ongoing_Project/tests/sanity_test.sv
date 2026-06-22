// =============================================================================
// sanity_test.sv  (SV-only starter scaffold)
// -----------------------------------------------------------------------------
// Directed test: mode-0, MSB-first, 8-bit transfer, single byte, loopback.
// Dispatched from tb_top via +TESTNAME=sanity_test.
//
// Public API: sanity_test::run(ref_model, coverage);
//
// The test itself is packaged as a class with a static run() task so that
// `tb_top.sv`'s dispatcher can call it by name without needing UVM. The BFMs
// (`tb_top.u_apb_bfm`, `tb_top.u_spi_bfm`) and the BFM control regs
// (`tb_top.bfm_mode`, `tb_top.bfm_pattern`) are reached via hierarchical
// reference, exactly as documented in apb_master_bfm.sv:
//
//     // This is *not* UVM - it is just a module with tasks that the test
//     // programs call via a hierarchical reference
//     // (`tb_top.u_apb_bfm.apb_write(...)`).
//
// Module names cannot be used as `ref` argument types in SV, so we keep the
// ref args strictly to scoreboard / coverage objects (which ARE classes).
// =============================================================================

`ifndef SANITY_TEST_SV
`define SANITY_TEST_SV

// Localparam aliases so the test body reads naturally without dragging in
// a `apb_master_bfm::` scope-resolution that requires the BFM to be a class.
// These mirror apb_master_bfm.sv exactly; if you change one, change the other.
localparam [7:0] APB_CTRL     = 8'h00;
localparam [7:0] APB_STATUS   = 8'h04;
localparam [7:0] APB_TX_DATA  = 8'h08;
localparam [7:0] APB_RX_DATA  = 8'h0C;
localparam [7:0] APB_CLK_DIV  = 8'h10;
localparam [7:0] APB_SS_CTRL  = 8'h14;
localparam [7:0] APB_INT_EN   = 8'h18;
localparam [7:0] APB_INT_STAT = 8'h1C;
localparam [7:0] APB_DELAY    = 8'h20;

class sanity_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);

        bit [31:0] rd;

        $display("[INFO] sanity_test: starting");

        //Read all registers reset values and sample them--------------------
        begin
        tb_top.u_apb_bfm.apb_read(APB_CTRL, rd); //rd is output
        coverage.sample_reg_reset_value(APB_CTRL, rd); //rd is sampled
        tb_top.u_apb_bfm.apb_read(APB_STATUS, rd); //rd is output
        coverage.sample_reg_reset_value(APB_STATUS, rd); //rd is sampled
        tb_top.u_apb_bfm.apb_read(APB_TX_DATA, rd); //rd is output
        coverage.sample_reg_reset_value(APB_TX_DATA, rd); //rd is sampled
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd); //rd is output
        coverage.sample_reg_reset_value(APB_RX_DATA, rd); //rd is sampled
        tb_top.u_apb_bfm.apb_read(APB_CLK_DIV, rd); //rd is output
        coverage.sample_reg_reset_value(APB_CLK_DIV, rd); //rd is sampled
        tb_top.u_apb_bfm.apb_read(APB_SS_CTRL, rd); //rd is output
        coverage.sample_reg_reset_value(APB_SS_CTRL, rd); //rd is sampled
        tb_top.u_apb_bfm.apb_read(APB_INT_EN, rd); //rd is output
        coverage.sample_reg_reset_value(APB_INT_EN, rd); //rd is sampled
        tb_top.u_apb_bfm.apb_read(APB_INT_STAT, rd); //rd is output
        coverage.sample_reg_reset_value(APB_INT_STAT, rd); //rd is sampled
        tb_top.u_apb_bfm.apb_read(APB_DELAY, rd); //rd is output
        coverage.sample_reg_reset_value(APB_DELAY, rd); //rd is sampled 
        end

        
        //TEST #1: Send A5 using slave MISO=========================================
        // Configure BFM slave pattern and mode
        tb_top.bfm_mode    = 2'b00;           // CPOL=0 CPHA=0
        tb_top.bfm_pattern = 8'hA5;

        // Enable DUT with loopback OFF, master, mode 0, MSB-first, 8-bit
        //   CTRL fields (from spec):
        //     [0] EN, [1] MSTR, [3:2] MODE, [4] LSB_FIRST, [5] LOOPBACK,
        //     [7:6] WIDTH (00=8b)
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0003);  // EN, MSTR
        ref_model.write_reg(APB_CTRL, 32'h0000_0003);
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0004);  // divide /4
        ref_model.write_reg(APB_CLK_DIV, 32'h0000_0004);
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,  32'h0000_000F);
        ref_model.write_reg(APB_INT_EN, 32'h0000_000F);

        coverage.sample_config(.mode(2'b00), .lsb_first(1'b0), .width(2'b00), .clk_div(16'h0004), .delay_val(8'h0), .loopback(1'b0));
        coverage.sample_reg_access(APB_CTRL, 1);
        coverage.sample_reg_access(APB_CLK_DIV, 1);
        coverage.sample_reg_access(APB_INT_EN, 1);

        // Push one byte, assert SS, wait for transfer done
        ref_model.predict_single_byte(.tx_byte(8'h5A),  //sent by apb master 
                                      .miso_pattern(tb_top.bfm_pattern), //sent by bfm slave
                                      .loopback(1'b0)); //no loopback, slave msg will arrive (A5q)

        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_005A);
        ref_model.write_reg(APB_TX_DATA, 32'h0000_005A);
        coverage.sample_reg_access(APB_TX_DATA, 1);
        

        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);  // assert ss[0] LOW
        ref_model.write_reg(APB_SS_CTRL, 32'h0000_0001);
        coverage.sample_reg_access(APB_SS_CTRL, 1);

        // Simple busy-poll via STATUS.BUSY (bit 0)o
        repeat (500) begin
            tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
            if (rd[0] == 1'b0) break;
        end

        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        scoreboard.check_rx(rd);

        //TEST #2: Send F3 using loopback=========================================
        // Configure BFM slave pattern and mode
        tb_top.bfm_mode    = 2'b00;           // CPOL=0 CPHA=0
        tb_top.bfm_pattern = 8'hA5;

        // Enable DUT with loopback OFF, master, mode 0, MSB-first, 8-bit
        //   CTRL fields (from spec):
        //     [0] EN, [1] MSTR, [3:2] MODE, [4] LSB_FIRST, [5] LOOPBACK,
        //     [7:6] WIDTH (00=8b)
        tb_top.u_apb_bfm.apb_write(APB_CTRL,    32'h0000_0023);  // EN, MSTR, loopback
        ref_model.write_reg(APB_CTRL, 32'h0000_0003);
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0004);  // divide /4
        ref_model.write_reg(APB_CLK_DIV, 32'h0000_0004);
        tb_top.u_apb_bfm.apb_write(APB_INT_EN,  32'h0000_000F);
        ref_model.write_reg(APB_INT_EN, 32'h0000_000F);

        coverage.sample_config(.mode(2'b00), .lsb_first(1'b0), .width(2'b00), .clk_div(16'h0004), .delay_val(8'h0), .loopback(1'b1));
        coverage.sample_reg_access(APB_CTRL, 1);
        coverage.sample_reg_access(APB_CLK_DIV, 1);
        coverage.sample_reg_access(APB_INT_EN, 1);

        // Push one byte, assert SS, wait for transfer done
        ref_model.predict_single_byte(.tx_byte(8'hF3),
                                      .miso_pattern(tb_top.bfm_pattern),
                                      .loopback(1'b1));

        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h0000_00F3);
        ref_model.write_reg(APB_TX_DATA, 32'h0000_00F3);
        coverage.sample_reg_access(APB_TX_DATA, 1);
        

        //tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);  // assert ss[0] LOW
        //ref_model.write_reg(APB_SS_CTRL, 32'h0000_0001);
        //coverage.sample_reg_access(APB_SS_CTRL, 1);

        // Simple busy-poll via STATUS.BUSY (bit 0)o
        repeat (500) begin
            tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
            if (rd[0] == 1'b0) break;
        end

        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        scoreboard.check_rx(rd);



        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0000);

        $display("[INFO] sanity_test: finished, errors=%0d",
                 ref_model.error_count);
    endtask

endclass

`endif // SANITY_TEST_SV
