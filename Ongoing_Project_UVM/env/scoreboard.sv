`ifndef SPI_SB_SV
`define SPI_SB_SV

class spi_scoreboard;

    localparam CTRL     = 8'h00;
    localparam STATUS   = 8'h04;
    localparam TX_DATA  = 8'h08;
    localparam RX_DATA  = 8'h0C;
    localparam CLK_DIV  = 8'h10;
    localparam SS_CTRL  = 8'h14;
    localparam INT_EN   = 8'h18;
    localparam INT_STAT = 8'h1C;
    localparam DELAY    = 8'h20;


    task check_rx(input bit [31:0] observed);
    bit [31:0] expected;
    if (spi_ref_model::exp_rx_queue.size() == 0) begin
        $display("[SCOREBOARD_ERROR] Unexpected RX read: queue is empty");
        spi_ref_model::error_count++;
        return;
    end
    expected = spi_ref_model::exp_rx_queue.pop_front();
    
    if (observed !== expected) begin
        $display("[SCOREBOARD_ERROR] RX data mismatch: predicted=0x%08h observed=0x%08h",
                 expected, observed);
        spi_ref_model::error_count++;
    end
    // Synchronize internal rx_fifo if needed (legacy)
    if (spi_ref_model::rx_fifo.size() > 0) void'(spi_ref_model::rx_fifo.pop_front());
    spi_ref_model::update_status();
    endtask

    task check_reg(input string name, input bit[7:0] addr, input bit[31:0] observed);
        bit [31:0] expected;
        if (addr == RX_DATA) begin
            expected = spi_ref_model::rx_fifo.size() > 0 ? spi_ref_model::rx_fifo.pop_front() : 32'h0;
            spi_ref_model::update_status();
        end else if (addr == TX_DATA) begin
            expected = 0; // Read returns 0
        end else begin
            expected = spi_ref_model::regs[addr/4];
        end
        
        if (observed !== expected) begin
            $display("[SCOREBOARD_ERROR] %s mismatch at 0x%02h: expected=0x%08h observed=0x%08h",
                     name, addr, expected, observed);
            spi_ref_model::error_count++;
        end
    endtask

endclass

`endif // SPI_SB_SV
