`ifndef RANDOMIZED_SANITY_TEST_SV
`define RANDOMIZED_SANITY_TEST_SV

class randomized_sanity_test;

    localparam [7:0] APB_CTRL     = 8'h00;
    localparam [7:0] APB_STATUS   = 8'h04;
    localparam [7:0] APB_TX_DATA  = 8'h08;
    localparam [7:0] APB_RX_DATA  = 8'h0C;
    localparam [7:0] APB_CLK_DIV  = 8'h10;
    localparam [7:0] APB_SS_CTRL  = 8'h14;
    localparam [7:0] APB_INT_EN   = 8'h18;
    localparam [7:0] APB_INT_STAT = 8'h1C;
    localparam [7:0] APB_DELAY    = 8'h20;


    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);

            spi_txn   t;
            bit [31:0] ctrl_word;
            bit [31:0] rd;
            int        seed;
            int        num_iterations = 50;

            $display("[INFO] randomized_sanity_test: starting %0d iterations for R1-R8 coverage", num_iterations);

            t = new();
            if ($value$plusargs("SEED=%d", seed))
                t.srandom(seed);

            for (int i = 0; i < num_iterations; i++) begin
                // Relaxed constraints to sweep all modes and widths
                if (!t.randomize() with {
                        mode      inside {[0:3]};
                        width     inside {2'b00, 2'b01, 2'b10}; 
                        lsb_first inside {0, 1};
                        loopback  inside {0, 1};
                        
                        // Targeted clk_div/delay patterns
                        if (i < 7) {
                            if (i == 0) clk_div == 0;
                            else if (i == 1) clk_div == 1;
                            else if (i == 2) clk_div == 2;
                            else if (i == 3) clk_div == 3;
                            else if (i == 4) clk_div == 255;
                            else if (i == 5) clk_div == 1024;
                            else if (i == 6) clk_div == 65535;
                        } else {
                            clk_div inside {[4:512]}; // Keep div sane for sim speed
                        }
                        delay_cfg inside {[0:255]};
                    }) begin
                    $display("[SCOREBOARD_ERROR] spi_txn randomization failed at iter %0d", i);
                    ref_model.error_count++;
                    continue;
                end

                $display("[INFO] Iter %0d: %s", i, t.sprint());

                // Sync Slave BFM
                tb_top.bfm_mode    = t.mode;
                tb_top.bfm_width   = t.width;
                tb_top.bfm_lsb     = t.lsb_first;
                tb_top.bfm_pattern = $urandom();

                // 1. Disable first and Sync Model
                tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0); 
                ref_model.write_reg(APB_CTRL, 32'h0);
                
                // 2. Set Config and Sync Model
                tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, {16'h0, t.clk_div});
                ref_model.write_reg(APB_CLK_DIV, {16'h0, t.clk_div});
                tb_top.u_apb_bfm.apb_write(APB_DELAY, {24'h0, t.delay_cfg});
                ref_model.write_reg(APB_DELAY, {24'h0, t.delay_cfg});
                tb_top.u_apb_bfm.apb_write(APB_INT_EN, 32'h0000_001F); // Mask
                ref_model.write_reg(APB_INT_EN, 32'h0000_001F);

                // 3. Set CTRL (EN=1) and Sync Model
                ctrl_word = 32'h0;
                ctrl_word[0]   = 1'b0;          // EN = 0  till we set the mode
                ctrl_word[1]   = 1'b1;          // MSTR
                ctrl_word[3:2] = t.mode;
                ctrl_word[4]   = t.lsb_first;
                ctrl_word[5]   = t.loopback;
                ctrl_word[7:6] = t.width;
                tb_top.u_apb_bfm.apb_write(APB_CTRL, ctrl_word);
                ref_model.write_reg(APB_CTRL, ctrl_word);

                // 3. Set CTRL (EN=1) and Sync Model
                ctrl_word[0]   = 1'b1;          // EN
                tb_top.u_apb_bfm.apb_write(APB_CTRL, ctrl_word);
                ref_model.write_reg(APB_CTRL, ctrl_word);

                // Sample coverage
                coverage.sample_config(.mode(t.mode),
                                       .lsb_first(t.lsb_first),
                                       .width(t.width),
                                       .clk_div(t.clk_div),
                                       .delay_val(t.delay_cfg),
                                       .loopback(t.loopback));

                // 4. Assert SS0
                tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);
                ref_model.write_reg(APB_SS_CTRL, 32'h0000_0001);

                // 5. Push TX Data and SYNC MODEL FIRST
                tb_top.u_apb_bfm.apb_write(APB_TX_DATA, t.tx_data);
                ref_model.write_reg(APB_TX_DATA, t.tx_data); // This pushes to ref_model's internal FIFO
                
                // 6. Predict (Now that FIFO has data)
                ref_model.predict_transfer(t);
                
                // Wait for DONE (Interrupt)
                ref_model.wait_for_interrupt();

                // 7. Wait for BUSY=0 (Handle slow clocks up to clk_div=65535)
                // 32 bits * 65536 cycles = ~2M cycles. 5M is safe.
                repeat (5000000) begin
                    tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
                    if (rd[0] == 1'b0) break;
                end

                // Read RX and Check
                tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
                scoreboard.check_rx(rd);

                // Cleanup
                tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0000);
                ref_model.write_reg(APB_SS_CTRL, 32'h0000_0000);
                tb_top.u_apb_bfm.apb_write(APB_INT_STAT, 32'hFFFF_FFFF); // Clear IRQ
                ref_model.write_reg(APB_INT_STAT, 32'hFFFF_FFFF);
            end

            $display("[INFO] randomized_sanity_test finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif // RANDOMIZED_SANITY_TEST_SV
