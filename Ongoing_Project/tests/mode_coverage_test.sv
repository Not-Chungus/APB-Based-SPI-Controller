`ifndef MODE_COVERAGE_TEST_SV
`define MODE_COVERAGE_TEST_SV

class mode_coverage_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;
        bit [31:0] test_data;
        bit [31:0] ctrl;
        
        $display("[INFO] mode_coverage_test: starting");

        for (int m = 0; m < 4; m++) begin
            for (int w = 0; w < 3; w++) begin
                for (int lsb = 0; lsb < 2; lsb++) begin
                    $display("[INFO] Testing Mode=%0d, Width=%0s, LSB=%0d", 
                             m, (w==0?"8b":w==1?"16b":"32b"), lsb);
                    
                    // 1. Configure DUT
                    // [7:6] width, [4] lsb, [3:2] mode, [1] mstr, [0] en off
                    ctrl = (w << 6) | (lsb << 4) | (m << 2) | 32'h0000_0002;

                    tb_top.u_apb_bfm.apb_write(8'h00, ctrl);
                    ref_model.write_reg(8'h00, ctrl);

                    // 1. Configure DUT
                    // [7:6] width, [4] lsb, [3:2] mode, [1] mstr, [0] en off
                    ctrl = ctrl | 32'h0000_0001;

                    tb_top.u_apb_bfm.apb_write(8'h00, ctrl);
                    ref_model.write_reg(8'h00, ctrl);
                    
                    // 2. Configure BFM
                    tb_top.bfm_mode    = m;
                    tb_top.bfm_width   = w;
                    tb_top.bfm_lsb     = lsb;
                    tb_top.bfm_pattern = $urandom();
                    
                    // 3. Sample Coverage
                    coverage.sample_config(m, lsb, w);
                    
                    // 4. Perform Transfer
                    test_data = $urandom();
                    ref_model.predict_single_byte(test_data, tb_top.bfm_pattern, 0);
                    
                    tb_top.u_apb_bfm.apb_write(8'h08, test_data);
                    ref_model.write_reg(8'h08, test_data);
                    
                    tb_top.u_apb_bfm.apb_write(8'h14, 32'h0000_0001); // SS_EN[0]=1
                    ref_model.write_reg(8'h14, 32'h0000_0001);
                    
                    // Wait for done
                    repeat (1000) begin
                        tb_top.u_apb_bfm.apb_read(8'h04, rd);
                        if (rd[0] == 0) break;
                    end
                    
                    // Check RX
                    tb_top.u_apb_bfm.apb_read(8'h0C, rd);
                    scoreboard.check_rx(rd);
                    
                    // Deassert SS
                    tb_top.u_apb_bfm.apb_write(8'h14, 32'h0000_0000);
                    ref_model.write_reg(8'h14, 32'h0000_0000);
                end
            end
        end

        $display("[INFO] mode_coverage_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif
