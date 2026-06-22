`ifndef REG_ACCESS_TEST_SV
`define REG_ACCESS_TEST_SV


//need more tests and randomized
class reg_access_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;
        bit [7:0] addrs[] = '{8'h00, 8'h04, 8'h08, 8'h0C, 8'h10, 8'h14, 8'h18, 8'h1C, 8'h20};
        string names[] = '{"CTRL", "STATUS", "TX_DATA", "RX_DATA", "CLK_DIV", "SS_CTRL", "INT_EN", "INT_STAT", "DELAY"};

        $display("[INFO] reg_access_test: starting");

        // 1. Reset values (R2)
        foreach (addrs[i]) begin
            tb_top.u_apb_bfm.apb_read(addrs[i], rd);
            scoreboard.check_reg(names[i], addrs[i], rd);
            coverage.sample_reg_access(addrs[i], 0);
        end

        // 2. Write-Read all R/W registers (R1)
        // CTRL
        tb_top.u_apb_bfm.apb_write(8'h00, 32'h0000_0055);
        ref_model.write_reg(8'h00, 32'h0000_0055);
        tb_top.u_apb_bfm.apb_read(8'h00, rd);
        scoreboard.check_reg("CTRL", 8'h00, rd);
        coverage.sample_reg_access(8'h00, 1);
        coverage.sample_reg_access(8'h00, 0);

        // STATUS
        tb_top.u_apb_bfm.apb_write(8'h04, 32'h0000_0055); //for coverage even tho read only
        ref_model.write_reg(8'h04, 32'h0000_0055);
        tb_top.u_apb_bfm.apb_read(8'h04, rd);
        scoreboard.check_reg("CTRL", 8'h04, rd);
        coverage.sample_reg_access(8'h04, 1);
        coverage.sample_reg_access(8'h04, 0);

        // RX DATA
        tb_top.u_apb_bfm.apb_write(8'h0C, 32'h0000_0055); //for coverage even tho read only
        ref_model.write_reg(8'h0C, 32'h0000_0055);
        tb_top.u_apb_bfm.apb_read(8'h0C, rd);
        scoreboard.check_reg("CTRL", 8'h0C, rd);
        coverage.sample_reg_access(8'h0C, 1);
        coverage.sample_reg_access(8'h0C, 0);

        // CLK_DIV
        tb_top.u_apb_bfm.apb_write(8'h10, 32'h0000_1234);
        ref_model.write_reg(8'h10, 32'h0000_1234);
        tb_top.u_apb_bfm.apb_read(8'h10, rd);
        scoreboard.check_reg("CLK_DIV", 8'h10, rd);
        coverage.sample_reg_access(8'h10, 1);

        // SS_CTRL
        tb_top.u_apb_bfm.apb_write(8'h14, 32'h0000_00AA);
        ref_model.write_reg(8'h14, 32'h0000_00AA);
        tb_top.u_apb_bfm.apb_read(8'h14, rd);
        scoreboard.check_reg("SS_CTRL", 8'h14, rd);
        coverage.sample_reg_access(8'h14, 1);

        // INT_EN
        tb_top.u_apb_bfm.apb_write(8'h18, 32'h0000_001F);
        ref_model.write_reg(8'h18, 32'h0000_001F);
        tb_top.u_apb_bfm.apb_read(8'h18, rd);
        scoreboard.check_reg("INT_EN", 8'h18, rd);
        coverage.sample_reg_access(8'h18, 1);

        // DELAY
        tb_top.u_apb_bfm.apb_write(8'h20, 32'h0000_00FF);
        ref_model.write_reg(8'h20, 32'h0000_00FF);
        tb_top.u_apb_bfm.apb_read(8'h20, rd);
        scoreboard.check_reg("DELAY", 8'h20, rd);
        coverage.sample_reg_access(8'h20, 1);

        // 3. Reserved offsets (R23)
        $display("[INFO] Checking reserved offsets (0x24, 0x28)");
        tb_top.u_apb_bfm.apb_read(8'h24, rd);
        if (rd !== 32'h0) begin
            $display("[CHECKER_ERROR] Reserved offset 0x24 did not return 0 (returned %0h)", rd);
            ref_model.error_count++;
        end
        tb_top.u_apb_bfm.apb_read(8'h28, rd);
        if (rd !== 32'h0) begin
            $display("[CHECKER_ERROR] Reserved offset 0x28 did not return 0 (returned %0h)", rd);
            ref_model.error_count++;
        end

        $display("[INFO] reg_access_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif
