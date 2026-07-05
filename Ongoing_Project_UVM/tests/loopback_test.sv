`ifndef LOOPBACK_TEST_SV
`define LOOPBACK_TEST_SV

class loopback_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;
        bit [31:0] tx_val = 32'h12345678;
        
        $display("[INFO] loopback_test: starting");

        // Enable loopback, 32-bit
        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_00A3); // LOOPBACK=1, WIDTH=32, EN=1, MSTR=1
        ref_model.write_reg(APB_CTRL, 32'h0000_00A3);
        
        tb_top.bfm_width = 2;
        tb_top.bfm_pattern  = 32'hFFFFFFFF; // Should be ignored in loopback


        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_val);
        ref_model.write_reg(APB_TX_DATA, tx_val);
        
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);
        ref_model.write_reg(APB_SS_CTRL, 32'h0000_0001);

        repeat (100) @(posedge tb_top.PCLK);
        
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        ref_model.predict_single_byte(tx_val, 32'hFFFFFFFF, 1); // loopback=1
        scoreboard.check_rx(rd);
        
        coverage.sample_config(.mode(0), .lsb_first(0), .width(2), .clk_div(0), .delay_val(0), .loopback(1));


        
        // Enable loopback, 16-bit
        tx_val = 32'h87654321;
        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0063); // LOOPBACK=1, WIDTH=16, EN=1, MSTR=1
        ref_model.write_reg(APB_CTRL, 32'h0000_0063);
        
        tb_top.bfm_width = 1;
        tb_top.bfm_pattern  = 32'hDEADBEEF; // Should be ignored in loopback


        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_val);
        ref_model.write_reg(APB_TX_DATA, tx_val);
        
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);
        ref_model.write_reg(APB_SS_CTRL, 32'h0000_0001);

        repeat (70) @(posedge tb_top.PCLK);
        
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        ref_model.predict_single_byte(tx_val, 32'hDEADBEEF, 1); // loopback=1
        scoreboard.check_rx(rd);
        
        coverage.sample_config(.mode(0), .lsb_first(0), .width(2), .clk_div(0), .delay_val(0), .loopback(1));



        // Enable loopback, 8-bit
        tx_val = 32'h16122004;
        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0023); // LOOPBACK=1, WIDTH=8, EN=1, MSTR=1
        ref_model.write_reg(APB_CTRL, 32'h0000_0023);
        
        tb_top.bfm_width = 1;
        tb_top.bfm_pattern  = 32'hBEEFDEAD; // Should be ignored in loopback


        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_val);
        ref_model.write_reg(APB_TX_DATA, tx_val);
        
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);
        ref_model.write_reg(APB_SS_CTRL, 32'h0000_0001);

        repeat (50) @(posedge tb_top.PCLK);
        
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        ref_model.predict_single_byte(tx_val, 32'hBEEFDEAD, 1); // loopback=1
        scoreboard.check_rx(rd);
        
        coverage.sample_config(.mode(0), .lsb_first(0), .width(2), .clk_div(0), .delay_val(0), .loopback(1));

        $display("[INFO] loopback_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif
