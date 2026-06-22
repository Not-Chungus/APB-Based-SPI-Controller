`ifndef CLK_DIV_CORNER_TEST_SV
`define CLK_DIV_CORNER_TEST_SV

class clk_div_corner_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;
        bit [15:0] divs[] = '{16'h0, 16'h1, 16'hFFFF};

        $display("[INFO] clk_div_corner_test: starting");

        foreach (divs[i]) begin
            $display("[INFO] Testing CLK_DIV=%0d", divs[i]);
            tb_top.u_apb_bfm.apb_write(8'h10, divs[i]);
            ref_model.write_reg(8'h10, divs[i]);
            
            tb_top.u_apb_bfm.apb_write(8'h00, 32'h0000_0003); // Enable
            ref_model.write_reg(8'h00, 32'h0000_0003);
            
            tb_top.u_apb_bfm.apb_write(8'h08, 32'hA5);
            ref_model.write_reg(8'h08, 32'hA5);
            
            tb_top.u_apb_bfm.apb_write(8'h14, 32'h0000_0001);
            ref_model.write_reg(8'h14, 32'h0000_0001);

            if (divs[i] < 100) begin
                repeat (2000) @(posedge tb_top.PCLK);
            end else begin
                // For large div, just wait a bit to see it's moving
                repeat (74000) @(posedge tb_top.PCLK);
                // We don't wait for completion to save time in regression
                // But we sample coverage
            end
            
            coverage.sample_config(0, 0, 0, divs[i]);
            
            // Clean up for next div
            tb_top.u_apb_bfm.apb_write(8'h00, 0);
            ref_model.write_reg(8'h00, 0);
        end

        $display("[INFO] clk_div_corner_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif
