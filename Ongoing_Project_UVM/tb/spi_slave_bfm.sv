
module spi_slave_bfm (
    spi_if.slave spi,
    input [1:0]  mode,
    input [31:0] miso_data,
    input [1:0]  width,
    input        lsb_first
);

    logic [31:0] shift_reg;
    int bit_idx;
    logic [5:0] total_bits;

    assign total_bits = (width == 2'b00) ? 8 :
                        (width == 2'b01) ? 16 : 32;

    logic cpol, cpha;
    assign cpol = mode[1];
    assign cpha = mode[0];

    wire leading_edge  = (cpol == 0) ? (spi.sclk == 1) : (spi.sclk == 0);
    wire trailing_edge = (cpol == 0) ? (spi.sclk == 0) : (spi.sclk == 1);

    // Initial load on SS_n
    always @(negedge spi.ss_n[0] or negedge spi.ss_n[1] or negedge spi.ss_n[2] or negedge spi.ss_n[3]) begin
        bit_idx = 0;
        shift_reg = miso_data;
        
        // In CPHA=0, drive first bit IMMEDIATELY
        // In CPHA=1, first bit is driven on the leading edge (handled below)
        if (cpha == 0) begin
            drive_miso();
        end else begin
            spi.miso = 1'bz; // Stay high-Z until leading edge
        end
    end

    always @(spi.sclk) begin
        if (spi.ss_n != 4'hF) begin
            if (cpha == 0) begin
                // CPHA=0: Drive subsequent bits on Trailing edge
                if (trailing_edge) advance_bit();
            end else begin
                // CPHA=1: Drive bits on Leading edge
                if (leading_edge) begin
                    drive_miso();
                    bit_idx++;
                    if (bit_idx >= total_bits) begin
                        bit_idx = 0;
                        shift_reg = miso_data;
                    end
                end
            end
        end
    end

    task drive_miso();
        if (lsb_first)
            spi.miso = shift_reg[bit_idx];//lsb first
        else
            spi.miso = shift_reg[total_bits - 1 - bit_idx];//MSB first
    endtask

    task advance_bit();
        bit_idx++;
        if (bit_idx >= total_bits) begin
            bit_idx = 0;
            shift_reg = miso_data;
        end
        drive_miso();
    endtask

endmodule
