`ifndef ERROR_INJECTION_TEST_SV
`define ERROR_INJECTION_TEST_SV

class error_injection_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;
        
        $display("[INFO] error_injection_test: starting");

        // 1. TX_DATA write when full
        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0003); // Enable
        ref_model.write_reg(APB_CTRL, 32'h0000_0003);
        
        for (int i=0; i<8; i++) tb_top.u_apb_bfm.apb_write(APB_TX_DATA, i);
        // This should cause OVF
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hDEADBEEF);
        ref_model.write_reg(APB_TX_DATA, 32'hDEADBEEF);
        
        tb_top.u_apb_bfm.apb_read(APB_STATUS, rd);
        if (rd[5] !== 1'b1) $display("[CHECKER_ERROR] STATUS.TX_OVF not set");
        coverage.sample_reg_access(APB_TX_DATA, 1);

        // 2. RX_DATA read when empty
        tb_top.u_apb_bfm.apb_read(APB_RX_DATA, rd);
        scoreboard.check_reg("RX_DATA_EMPTY", 8'h0C, rd);
        coverage.sample_reg_access(APB_RX_DATA, 0);

        // 3. Reserved offsets (0x24)
        tb_top.u_apb_bfm.apb_read(8'h24, rd);
        if (rd !== 0) $display("[CHECKER_ERROR] Reserved offset 0x24 did not return 0");
        coverage.sample_reg_access(8'h24, 0);

        // 5. Illegal address access (0x40) - Target R23
        $display("[INFO] Testing R23: Illegal address access to 0x40");
        tb_top.u_apb_bfm.apb_write(8'h40, 32'hDEADBEEF); 
        coverage.sample_reg_access(8'h40, 1);

        $display("[INFO] error_injection_test: finished, errors=%0d", ref_model.error_count);
    endtask

endclass

`endif
