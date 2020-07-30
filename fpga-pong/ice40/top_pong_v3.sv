// Project F: FPGA Pong - Top v3 (iCEBreaker with 12-bit DVI Pmod)
// (C)2020 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none

module top_pong_v3 (
    input  wire logic clk_12m,      // 12 MHz clock
    input  wire logic btn_rst,      // reset button (active high)
    input  wire logic btn_up,       // up button
    input  wire logic btn_ctrl,     // control button
    input  wire logic btn_dn,       // down button
    output      logic dvi_clk,      // DVI pixel clock
    output      logic dvi_hsync,    // DVI horizontal sync
    output      logic dvi_vsync,    // DVI vertical sync
    output      logic dvi_de,       // DVI data enable
    output      logic [3:0] dvi_r,  // 4-bit DVI red
    output      logic [3:0] dvi_g,  // 4-bit DVI green
    output      logic [3:0] dvi_b   // 4-bit DVI blue
    );

    // generate pixel clock
    logic clk_pix;
    logic clk_locked;
    clock_gen clock_640x480 (
       .clk(clk_12m),
       .rst(btn_rst),
       .clk_pix,
       .clk_locked
    );

    // display timings
    localparam CORDW = 10;  // screen coordinate width in bits
    logic [CORDW-1:0] sx, sy;
    logic de;
    display_timings timings_640x480 (
        .clk_pix,
        .rst(!clk_locked),  // wait for clock lock
        .sx,
        .sy,
        .hsync(dvi_hsync),
        .vsync(dvi_vsync),
        .de
    );

    // size of screen (excluding blanking)
    localparam H_RES = 640;
    localparam V_RES = 480;

    logic animate;  // high for one clock tick at start of blanking
    always_comb animate = (sy == 480 && sx == 0);

    // debounce buttons
    logic sig_ctrl, move_up, move_dn;
    debounce deb_btn_ctrl (.clk(clk_pix), .in(btn_ctrl), .out(), .ondn(), .onup(sig_ctrl));
    debounce deb_btn_up (.clk(clk_pix), .in(btn_up), .out(move_up), .ondn(), .onup());
    debounce deb_btn_dn (.clk(clk_pix), .in(btn_dn), .out(move_dn), .ondn(), .onup());

    // game state
    enum {IDLE, PLAY} state, state_next;
    always_comb begin
        state_next = IDLE;
        case(state)
            IDLE: state_next = (sig_ctrl) ? PLAY : IDLE;
            PLAY: state_next = (sig_ctrl) ? IDLE : PLAY;
        endcase
    end

    always_ff @(posedge clk_pix) begin
        state <= state_next;
    end

    // paddles
    localparam P_HEIGHT = 40;       // height in pixels
    localparam P_WIDTH  = 10;       // width in pixels
    localparam P_SPEED  = 4;        // speed
    localparam P_OFFSET = 32;       // offset from screen edge
    logic [CORDW-1:0] p1y, p2y;     // vertical position of paddles 1 and 2

    always_ff @(posedge clk_pix) begin
        if (animate) begin
            if (state == PLAY) begin  // human paddle 1
                if (move_up) begin
                    if (p1y > P_SPEED) p1y <= p1y - P_SPEED;  // at top?
                end
                if (move_dn) begin
                    if (p1y < V_RES - (P_HEIGHT + P_SPEED)) p1y <= p1y + P_SPEED;  // at bottom?
                end
            end else begin  // "AI" paddle 1
                if ((p1y + P_HEIGHT/2) < by) begin  // top of ball is below
                    if (p1y < V_RES - (P_HEIGHT + P_SPEED)) p1y <= p1y + P_SPEED;  // screen bottom?
                end
                if ((p1y + P_HEIGHT/2) > (by + B_SIZE)) begin  // bottom of ball is above
                    if (p1y > P_SPEED) p1y <= p1y - P_SPEED;  // screen top?
                end
            end

            // "AI" paddle 2
            if ((p2y + P_HEIGHT/2) < by) begin
                if (p2y < V_RES - (P_HEIGHT + P_SPEED)) p2y <= p2y + P_SPEED;
            end
            if ((p2y + P_HEIGHT/2) > (by + B_SIZE)) begin
                if (p2y > P_SPEED) p2y <= p2y - P_SPEED;
            end
        end
    end

    logic p1_draw, p2_draw;
    always_comb begin  // are paddles at current screen position?
        p1_draw = (sx >= P_OFFSET) && (sx < P_OFFSET + P_WIDTH)
               && (sy >= p1y) && (sy < p1y + P_HEIGHT);
        p2_draw = (sx >= H_RES - P_OFFSET - P_WIDTH) && (sx < H_RES - P_OFFSET)
               && (sy >= p2y) && (sy < p2y + P_HEIGHT);
    end

    // paddle collision detection
    logic p1_col, p2_col;
    always_ff @(posedge clk_pix) begin
        if (animate) begin
            p1_col <= 0;
            p2_col <= 0;
        end else if (b_draw) begin
            if (p1_draw) p1_col <= 1;
            if (p2_draw) p2_col <= 1;
        end
    end

    // ball
    localparam B_SIZE = 8;      // size in pixels
    logic [CORDW-1:0] bx, by;   // position
    logic dx, dy;               // direction: 0 is right/down
    logic [3:0] spx = 4'd6;     // horizontal speed
    logic [3:0] spy = 4'd4;     // vertical speed

    always_ff @(posedge clk_pix) begin
        if (animate) begin
            if (p1_col) begin  // left paddle collision
                dx <= 0;
                bx <= bx + spx;
            end else if (p2_col) begin  // right paddle collision
                dx <= 1;
                bx <= bx - spx;
            end else if (bx >= H_RES - (spx + B_SIZE)) begin  // right edge
                dx <= 1;
                bx <= bx - spx;
            end else if (bx < spx) begin  // left edge
                dx <= 0;
                bx <= bx + spx;
            end else bx <= (dx) ? bx - spx : bx + spx;

            if (by >= V_RES - (spy + B_SIZE)) begin  // bottom edge
                dy <= 1;
                by <= by - spy;
            end else if (by < spy) begin  // top edge
                dy <= 0;
                by <= by + spy;
            end else by <= (dy) ? by - spy : by + spy;
        end
    end

    logic b_draw;  // is ball at current screen position?
    always_comb begin
        b_draw = (sx >= bx) && (sx < bx + B_SIZE)
              && (sy >= by) && (sy < by + B_SIZE);
    end

    // DVI output
    always_comb begin
        dvi_clk = clk_pix;
        dvi_de  = de;
        dvi_r = !de ? 4'h0 : ((b_draw | p1_draw | p2_draw) ? 4'hF : 4'h0);
        dvi_g = !de ? 4'h0 : ((b_draw | p1_draw | p2_draw) ? 4'hF : 4'h0);
        dvi_b = !de ? 4'h0 : ((b_draw | p1_draw | p2_draw) ? 4'hF : 4'h0);
    end
endmodule