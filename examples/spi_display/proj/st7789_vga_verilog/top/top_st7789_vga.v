module top_st7789_vga
(
    input  wire clk_25mhz,
    input  wire [6:0] btn,
    output wire [7:0] led,
    output wire oled_csn,
    output wire oled_clk,
    output wire oled_mosi,
    output wire oled_dc,
    output wire oled_resn
);
  assign wifi_en = 1;
  assign wifi_gpio0 = btn[0];

  localparam c_clk_pixel_mhz = 25;
  localparam c_clk_spi_mhz = 4*c_clk_pixel_mhz; // *4 or more

  // clock generator
  wire clk_locked;
  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz( c_clk_spi_mhz*1000000),
    .out1_hz( c_clk_pixel_mhz*1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(clk_locked)
  );
  wire clk_lcd = clocks[0];
  wire clk_pixel = clocks[1];

  wire S_reset = ~btn[0] | btn[1];

  // test picture video generator for debug purposes
  wire vga_hsync_test;
  wire vga_vsync_test;
  wire vga_blank_test;
  wire [7:0] vga_r_test, vga_g_test, vga_b_test;
  vga
  #(
    .c_resolution_x(240),
    .c_hsync_front_porch(1800),
    .c_hsync_pulse(1),
    .c_hsync_back_porch(1800),
    .c_resolution_y(240),
    .c_vsync_front_porch(1),
    .c_vsync_pulse(1),
    .c_vsync_back_porch(1),
    .c_bits_x(12),
    .c_bits_y(8)
  )
  vga_instance
  (
    .clk_pixel(clk_pixel),
    .clk_pixel_ena(1'b1),
    .test_picture(1'b1),
    .vga_r(vga_r_test),
    .vga_g(vga_g_test),
    .vga_b(vga_b_test),
    .vga_hsync(vga_hsync_test),
    .vga_vsync(vga_vsync_test),
    .vga_blank(vga_blank_test)
  );
  wire [15:0] vga_rgb_test = {vga_r_test[7:3],vga_g_test[7:2],vga_b_test[7:3]};

  assign led[0] = ~vga_blank_test;
  assign led[1] = vga_hsync_test;
  assign led[2] = vga_vsync_test;
  assign led[3] = ~oled_resn;
  assign led[7:4] = 0;

  lcd_video
  #(
    .c_clk_spi_mhz(c_clk_spi_mhz),
    .c_vga_sync(1),
    .c_reset_us(1000),
    //.c_init_file("st7789_linit_long.mem"),
    //.c_init_size(75), // long init
    //.c_init_size(35), // standard init (not long)
    .c_clk_phase(0),
    .c_clk_polarity(1),
    .c_x_size(240),
    .c_y_size(240),
    .c_color_bits(16)
  )
  lcd_video_instance
  (
    .reset(S_reset),
    .clk_pixel(clk_pixel), // 25 MHz
    .clk_pixel_ena(1),
    .clk_spi(clk_lcd), // 100 MHz
    .clk_spi_ena(1),
    .blank(vga_blank_test),
    .hsync(vga_hsync_test),
    .vsync(vga_vsync_test),
    .color(vga_rgb_test),
    .spi_resn(oled_resn),
    .spi_clk(oled_clk),
    //.spi_csn(oled_csn), // 8-pin ST7789
    .spi_dc(oled_dc),
    .spi_mosi(oled_mosi)
  );
  assign oled_csn = 1; // 7-pin ST7789

endmodule
