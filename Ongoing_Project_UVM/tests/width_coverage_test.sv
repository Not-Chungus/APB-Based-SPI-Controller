`ifndef WIDTH_COVERAGE_TEST_SV
`define WIDTH_COVERAGE_TEST_SV

class width_coverage_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;
        bit [1:0] widths[] = '{2'b00, 2'b01, 2'b10};
        bit [31:0] test_vals[] = '{32'hA5, 32'h1234, 32'hDEADBEEF};

        $display("[INFO] width_coverage_test: starting");

        foreach (widths[i]) begin
            // Configure width
            tb_top.u_apb_bfm.apb_write(8'h00, (widths[i] << 6) | 32'h0000_0003);
            ref_model.write_reg(8'h00, (widths[i] << 6) | 32'h0000_0003);
            
            tb_top.bfm_width = widths[i];
            tb_top.bfm_pattern  = ~test_vals[i]; // Different from TX

            // Push data
            tb_top.u_apb_bfm.apb_write(8'h08, test_vals[i]);
            ref_model.write_reg(8'h08, test_vals[i]);
            
            // Predict BEFORE transfer
            ref_model.predict_single_byte(test_vals[i], tb_top.bfm_pattern, 0);

            // Assert SS (Starts transfer)
            tb_top.u_apb_bfm.apb_write(8'h14, 32'h0000_0001);
            ref_model.write_reg(8'h14, 32'h0000_0001);

            // Wait for transfer to finish
            repeat (100) @(posedge tb_top.PCLK);
            
            // Read and check
            tb_top.u_apb_bfm.apb_read(8'h0C, rd);
            scoreboard.check_rx(rd);

            // Deassert SS to reset BFM for next width
            tb_top.u_apb_bfm.apb_write(8'h14, 32'h0000_0000);
            ref_model.write_reg(8'h14, 32'h0000_0000);
            //repeat (100) @(posedge tb_top.PCLK);
            
            coverage.sample_config(0, 0, widths[i]);
        end

        $display("[INFO] width_coverage_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif
