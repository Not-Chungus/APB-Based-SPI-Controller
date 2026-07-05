`ifndef DELAY_TRANSFER_TEST_SV
`define DELAY_TRANSFER_TEST_SV

class delay_transfer_test;


    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;

        int clk_div_func = 4;
        int delay_cfg_func = 64;

        int expected_delay;
        int count;

        

        
        $display("[INFO] delay_transfer_test: starting");

        
        // 1. Configure Delay = 32 
        tb_top.u_apb_bfm.apb_write(APB_DELAY, 32'h0000_0020); // 32 half-cycles
        ref_model.write_reg(APB_DELAY, 32'h0000_0020);    
        
        tb_top.u_apb_bfm.apb_write(APB_CLK_DIV, 32'h0000_0004);  // divide /4
        ref_model.write_reg(APB_CLK_DIV, 32'h0000_0004);

        tb_top.u_apb_bfm.apb_write(APB_CTRL, 32'h0000_0003); // Enable, MSTR
        ref_model.write_reg(APB_CTRL, 32'h0000_0003);
        

        tb_top.u_apb_bfm.apb_read(APB_DELAY, rd);
        if (rd[7:0] !== 32) begin
            $display("[CHECKER_ERROR] new delay  not set ");
            ref_model.error_count++;
        end
        

        //CASE1: Normal Delay of 32============================
        // Push 3 words
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hA5);
        ref_model.write_reg(APB_TX_DATA, 32'hA5);
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h5A);
        ref_model.write_reg(APB_TX_DATA, 32'h5A);
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hBA);
        ref_model.write_reg(APB_TX_DATA, 32'hBA);
        
        tb_top.u_apb_bfm.apb_write(APB_SS_CTRL, 32'h0000_0001);
        ref_model.write_reg(APB_SS_CTRL, 32'h0000_0001);
        coverage.sample_config(.mode(0), .lsb_first(0), .width(0), .clk_div(4), .delay_val(32));
        
        repeat (1000) @(posedge tb_top.PCLK); //this is now in delay between 1st and 2nd word



        //CASE2: NEW DELAY DURING 1st Write
        // Push 2 words
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hA5);
        ref_model.write_reg(APB_TX_DATA, 32'hA5);
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h5A);
        ref_model.write_reg(APB_TX_DATA, 32'h5A);

        repeat (40) @(posedge tb_top.PCLK); //this is now in delay between 1st and 2nd word

        tb_top.u_apb_bfm.apb_write(APB_DELAY, 32'h0000_0010); // 16 half-cycles
        ref_model.write_reg(APB_DELAY, 32'h0000_0010);

        tb_top.u_apb_bfm.apb_read(APB_DELAY, rd);
        if (rd[7:0] !== 16) begin
            $display("[CHECKER_ERROR] new delay  not set ");
            ref_model.error_count++;
        end
        repeat (500) @(posedge tb_top.PCLK); //wait for both words befor next Case



        //CASE3: NEW DELAY DURING DELAY
        // Push 2 words
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'hA5);
        ref_model.write_reg(APB_TX_DATA, 32'hA5);
        tb_top.u_apb_bfm.apb_write(APB_TX_DATA, 32'h5A);
        ref_model.write_reg(APB_TX_DATA, 32'h5A);

        repeat (40) @(posedge tb_top.PCLK); //this is now in delay between 1st and 2nd word?????!!!

        tb_top.u_apb_bfm.apb_write(APB_DELAY, 32'h0000_0040); // 64 half-cycles
        ref_model.write_reg(APB_DELAY, 32'h0000_0040);

        tb_top.u_apb_bfm.apb_read(APB_DELAY, rd);
        if (rd[7:0] !== 64) begin
            $display("[CHECKER_ERROR]  new delay  not set ");
            ref_model.error_count++;
        end
        
        repeat (2000) @(posedge tb_top.PCLK);



        $display("[INFO] delay_transfer_test: finished, errors=%0d", ref_model.error_count);
    endtask



        


endclass

`endif
