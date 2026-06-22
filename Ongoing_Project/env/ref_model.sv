// =============================================================================
// ref_model.sv  (SV-only starter scaffold)
// -----------------------------------------------------------------------------
// A plain-SV reference model + scoreboard. It does not use UVM - it is a
// simple class that students instantiate from tb_top (`spi_ref_model u_ref =
// new();`) and update from their test programs.
//
// Students should extend this class to model the full spec: for the scaffold
// we model just enough to check the sanity_test.
// =============================================================================

`ifndef SPI_REF_MODEL_SV
`define SPI_REF_MODEL_SV

class spi_ref_model;

    static int error_count = 0;

    // Model state
    static bit [31:0] regs [9];
    static bit [31:0] tx_fifo [$];
    static bit [31:0] rx_fifo [$];

    // Offsets
    localparam CTRL     = 8'h00;
    localparam STATUS   = 8'h04;
    localparam TX_DATA  = 8'h08;
    localparam RX_DATA  = 8'h0C;
    localparam CLK_DIV  = 8'h10;
    localparam SS_CTRL  = 8'h14;
    localparam INT_EN   = 8'h18;
    localparam INT_STAT = 8'h1C;
    localparam DELAY    = 8'h20;

    function new();
        error_count = 0;
        reset();
    endfunction

    function void reset();
        regs[CTRL/4]     = 32'h0;
        regs[STATUS/4]   = 32'h0000_0014; // RX_EMPTY=1, TX_EMPTY=1 (bits 4, 2)
        regs[TX_DATA/4]  = 32'h0;
        regs[RX_DATA/4]  = 32'h0;
        regs[CLK_DIV/4]  = 32'h0;
        regs[SS_CTRL/4]  = 32'h0;
        regs[INT_EN/4]   = 32'h0;
        regs[INT_STAT/4] = 32'h0;

        regs[DELAY/4]    = 32'h0;
        tx_fifo.delete();
        rx_fifo.delete();
    endfunction

    static function void update_status();
        bit old_tx_empty = regs[STATUS/4][2];
        
        // bit 0: BUSY
        // bit 1: TX_FULL
        regs[STATUS/4][1] = (tx_fifo.size() == 8);
        // bit 2: TX_EMPTY
        regs[STATUS/4][2] = (tx_fifo.size() == 0);
        // bit 3: RX_FULL
        regs[STATUS/4][3] = (rx_fifo.size() == 8);
        // bit 4: RX_EMPTY
        regs[STATUS/4][4] = (rx_fifo.size() == 0);

        // Interrupt events
        if (!old_tx_empty && regs[STATUS/4][2]) regs[INT_STAT/4][0] = 1'b1; // TX_EMPTY event
    endfunction


    function void write_reg(input bit[7:0] addr, input bit[31:0] data);
        case (addr)
            CTRL: begin
                bit old_en = regs[CTRL/4][0];
                regs[CTRL/4] = data & 32'h0000_00FF; // Only low 8 bits
                if (old_en && !regs[CTRL/4][0]) begin
                    // CTRL.EN 1->0 flushes FIFOs and resets shifter (R3/R22)
                    tx_fifo.delete();
                    rx_fifo.delete();
                    update_status();
                end
            end
            TX_DATA: begin
                if (regs[CTRL/4][0]) begin // Push ignored if EN=0
                    if (tx_fifo.size() < 8) begin
                        bit [1:0] width = regs[CTRL/4][7:6];
                        bit [31:0] mask = (width == 2'b00) ? 32'hFF :
                                          (width == 2'b01) ? 32'hFFFF : 32'hFFFF_FFFF;
                        tx_fifo.push_back(data & mask);
                    end else begin
                        // Overflow (R13)
                        regs[STATUS/4][5]   = 1'b1; // TX_OVF sticky in STATUS
                        regs[INT_STAT/4][2] = 1'b1; // TX_OVF in INT_STAT
                    end
                    update_status();
                end
            end
            CLK_DIV:  regs[CLK_DIV/4]  = data & 32'h0000_FFFF;
            SS_CTRL:  regs[SS_CTRL/4]  = data & 32'h0000_00FF;
            INT_EN:   regs[INT_EN/4]   = data & 32'h0000_001F;
            INT_STAT: regs[INT_STAT/4] &= ~data; // W1C
            DELAY:    regs[DELAY/4]    = data & 32'h0000_00FF;
            default: ; // Reserved or RO
        endcase
    endfunction

    // Called by test when a transfer is seen/expected to finish
    function void transfer_complete(input bit[31:0] rx_word);
        if (tx_fifo.size() > 0) void'(tx_fifo.pop_front());
        
        if (rx_fifo.size() < 8) begin
            bit [1:0] width = regs[CTRL/4][7:6];
            bit [31:0] mask = (width == 2'b00) ? 32'hFF :
                              (width == 2'b01) ? 32'hFFFF : 32'hFFFF_FFFF;
            rx_fifo.push_back(rx_word & mask);
        end else begin
            // RX Overflow (R14)
            regs[STATUS/4][6]   = 1'b1;
            regs[INT_STAT/4][3] = 1'b1;
        end
        
        regs[INT_STAT/4][4] = 1'b1; // TRANSFER_DONE
        if (tx_fifo.size() == 0) regs[INT_STAT/4][0] = 1'b1; // TX_EMPTY
        if (rx_fifo.size() == 8) regs[INT_STAT/4][1] = 1'b1; // RX_FULL
        update_status();
    endfunction



    // Scoreboard queue
    static bit [31:0] exp_rx_queue [$];

    task predict_single_byte(input bit[31:0] tx_byte, input bit[31:0] miso_pattern, input bit loopback);
        bit [31:0] mask;
        bit [31:0] pred_rx_byte;
        bit [1:0] w_cfg = regs[CTRL/4][7:6];
        bit [5:0] w = (w_cfg == 2'b00) ? 8 : (w_cfg == 2'b01) ? 16 : 32;
        
        mask = (w == 32) ? 32'hFFFF_FFFF : (32'h1 << w) - 32'h1;
        pred_rx_byte = (loopback ? tx_byte : miso_pattern) & mask;
        
        exp_rx_queue.push_back(pred_rx_byte);
        transfer_complete(pred_rx_byte);
    endtask



    // --- Enhanced API for Coverage Tests ---

    task predict_transfer(input spi_txn t);
        predict_single_byte(t.tx_data, tb_top.bfm_pattern, t.loopback);
    endtask

    task wait_for_interrupt();
        // Wait for IRQ pin or timeout to prevent hangs
        fork
            begin
                wait(tb_top.spi.irq === 1'b1);
            end
            begin
                repeat (10000000) @(posedge tb_top.PCLK);
                $display("[CHECKER_ERROR] wait_for_interrupt timed out after 10000000 cycles");
                error_count++;
            end
        join_any
        disable fork;
    endtask

endclass


`endif // SPI_REF_MODEL_SV
