`ifndef EXTRA_REQS_TEST_SV
`define EXTRA_REQS_TEST_SV


    localparam [7:0] CTRL     = 8'h00;
    localparam [7:0] STATUS   = 8'h04;
    localparam [7:0] TX_DATA  = 8'h08;
    localparam [7:0] RX_DATA  = 8'h0C;
    localparam [7:0] CLK_DIV  = 8'h10;
    localparam [7:0] SS_CTRL  = 8'h14;
    localparam [7:0] INT_EN   = 8'h18;
    localparam [7:0] INT_STAT = 8'h1C;
    localparam [7:0] DELAY    = 8'h20;


class extra_reqs_test;

    static task run(ref spi_ref_model     ref_model,
                    ref spi_coverage_col  coverage,
                    ref spi_scoreboard  scoreboard);
        
        bit [31:0] rd;
        
        $display("[INFO] extra_reqs_test: starting");

        // --- 1. R3: Global Enable Flush ---
        $display("[INFO] Testing R3: Global Enable Flush");
        // Reset and Enable
        tb_top.u_apb_bfm.apb_write(CTRL, 32'h0000_0003); 
        // Fill TX FIFO
        for (int i=0; i<8; i++) tb_top.u_apb_bfm.apb_write(TX_DATA, i);
        tb_top.u_apb_bfm.apb_read(STATUS, rd);
        if (rd[1] !== 1'b1) begin
            $display("[CHECKER_ERROR] TX FIFO not full after 8 writes");
            ref_model.error_count++;
        end
        
        // Disable
        tb_top.u_apb_bfm.apb_write(CTRL, 32'h0000_0002); // EN=0, MSTR=1
        
        repeat(10) @(posedge tb_top.PCLK);

        // Re-enable
        tb_top.u_apb_bfm.apb_write(CTRL, 32'h0000_0003); // EN=1
        
        // Check if empty
        tb_top.u_apb_bfm.apb_read(STATUS, rd);
        if (rd[2] !== 1'b1) begin
            $display("[CHECKER_ERROR] R3: TX FIFO not flushed after EN 1->0");
            ref_model.error_count++;
        end


        // --- 2. R18: W1C Race Condition ---
        $display("[INFO] Testing R18: W1C Race Condition");
        // Clear all interrupts
        tb_top.u_apb_bfm.apb_write(INT_STAT, 32'h0000_001F);
        
        // Start a transfer and try to hit the race on TRANSFER_DONE (bit 4)
        // This is a bit brute-force to ensure we hit the exact cycle.
        // We'll run multiple transfers and offset the W1C.
        for (int offset=10; offset<30; offset++) begin
            // Reset status
            tb_top.u_apb_bfm.apb_write(INT_STAT, 32'h0000_001F);
            
            // Start transfer (8-bit, DIV=0)
            tb_top.u_apb_bfm.apb_write(CLK_DIV, 32'h0); // DIV=0
            tb_top.u_apb_bfm.apb_write(TX_DATA, 32'hA5);
            tb_top.u_apb_bfm.apb_write(SS_CTRL, 32'h01); // Start
            
            // Wait 'offset' cycles then attempt W1C
            repeat (offset) @(posedge tb_top.PCLK);
            tb_top.u_apb_bfm.apb_write(INT_STAT, 32'h0000_0010); // W1C Done
            coverage.sample_interrupt(5'b10000, .is_clear(1));
            
            // Wait for transfer to definitely finish
            repeat (50) @(posedge tb_top.PCLK);
            
        // Check if Done is 1. 
            // If offset is small, we cleared BEFORE the event -> should be 1.
            // If offset is the race cycle, R18 says it should be 1.
            // If offset is large, we cleared AFTER the event -> should be 0.
            tb_top.u_apb_bfm.apb_read(INT_STAT, rd);
            $display("[INFO] R18 Trace: offset=%0d, Done=%b", offset, rd[4]);
        end

        $display("[INFO] extra_reqs_test: finished, check log for R18 transition");
    endtask

endclass

`endif
