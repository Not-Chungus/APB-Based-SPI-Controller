`ifndef FIFO_STRESS_TEST_SV
`define FIFO_STRESS_TEST_SV



class fifo_stress_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;
        bit [31:0] tx_data [8];
        bit [31:0] rx_data [8];
        
        $display("[INFO] fifo_stress_test: starting");

        // 0. Reset and Configure Basic Settings
        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0); 
        ref_model.write_reg(APB_CTRL, 32'h0);
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0); 
        ref_model.write_reg(APB_SS_CTRL, 32'h0);
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0); // Fast
        ref_model.write_reg(APB_CLK_DIV, 32'h0);

        // 1. Enable Core with 32-bit Mode, BUT keep SS Idle (SS_n=4'hF)
        // This prevents the core from starting while we fill the FIFO.
        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0083);
        ref_model.write_reg(APB_CTRL, 32'h0000_0083);
        
        tb_top.bfm_mode  = 0;
        tb_top.bfm_width = 2; // 32b
        tb_top.bfm_lsb   = 0;
        tb_top.bfm_pattern = 32'h1234_5678;

        // 2. Fill TX FIFO (8 words)
        for (int i = 0; i < 8; i++) begin
            tx_data[i] = $urandom();
            tb_top.u_apb_bfm.apb_write(APB_TX_DATA, tx_data[i]);
            ref_model.write_reg(APB_TX_DATA, tx_data[i]);
            coverage.sample_fifo(i+1, 0);
            // Predict now that CTRL is set correctly
            ref_model.predict_single_byte(tx_data[i], 32'h1234_5678, 0);
        end

        /// 5. Check TX FIFO Full 
        tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
        if (rd[1] !== 1'b1) $display("[CHECKER_ERROR] TX_FULL not set after 8 transfers, status=0x%h", rd);
        coverage.sample_fifo(0, 8);
        
        // 3. Assert SS0 to start the 8-word burst
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);
        ref_model.write_reg(APB_SS_CTRL, 32'h0000_0001);

        // 4. Wait for ENTIRE BURST to complete (BUSY=0 and TX_EMPTY=1)
        // We must check both because BUSY may toggle between words.
        repeat (5000000) begin
            tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
            if (rd[0] == 1'b0 && rd[2] == 1'b1) break;
        end

        // 5. Check RX FIFO Full and Drain
        tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
        if (rd[3] !== 1'b1) $display("[CHECKER_ERROR] RX_FULL not set after 8 transfers, status=0x%h", rd);
        coverage.sample_fifo(0, 8); 

        for (int i = 0; i < 8; i++) begin
            tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
            scoreboard.check_rx(rd);
            coverage.sample_fifo(0, 7-i);
        end

        /// 5. Check RX FIFO empty and Drain
        tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
        if (rd[4] !== 1'b1) $display("[CHECKER_ERROR] RX_EMPTY not set after 8 transfers, status=0x%h", rd);
        coverage.sample_fifo(0, 8);

        // Cleanup
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0000);
        ref_model.write_reg(APB_SS_CTRL, 32'h0000_0000);
        tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF);
        ref_model.write_reg(APB_INT_STAT, 32'hFFFF_FFFF);

        $display("[INFO] fifo_stress_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif



        

        
