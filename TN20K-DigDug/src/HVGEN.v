module HVGEN
(
	output  [8:0]		HPOS,
	output  [8:0]		VPOS,
	input 				PCLK,
	input	 [11:0]		iRGB,

	output reg [11:0]	oRGB,
	output reg			HBLK = 1,
	output reg			VBLK = 1,
	output reg			HSYN = 1,
	output reg			VSYN = 1
);

reg [8:0] hcnt = 0;
reg [8:0] vcnt = 0;

assign HPOS = hcnt;
assign VPOS = vcnt;

always @(posedge PCLK) begin
	case (hcnt) //Mas optimo de mmtno 288 312 384 - 289/313/385 - 290/314/386 - 291/315/387 - 292/316/388
					//Probadas mal 287/311/383 - 288/311/383 - 289/311/383 <-use this original
					//Probadas mal 294/316/388 - 
		// blanking from 288 (shows pixels 1-288, the width of the picture). Sync after a
		// front porch, as the Mappy core (hvgen.v): without one, VGA monitors shift the
		// picture right and lose the right-hand columns
		288: begin HBLK <= 1; hcnt <= hcnt+1; end
		311: begin HSYN <= 0; hcnt <= hcnt+1; end
		342: begin HSYN <= 1; hcnt <= hcnt+1; end
		383: begin                                             //383
			HBLK <= 0; HSYN <= 1; hcnt <= 0;
			case (vcnt)
				223: begin VBLK <= 1; vcnt <= vcnt+1; end
				226: begin VSYN <= 0; vcnt <= vcnt+1; end
				233: begin VSYN <= 1; vcnt <= vcnt+1; end
				262: begin VBLK <= 0; vcnt <= 0; end
				default: vcnt <= vcnt+1;
			endcase
		end
		default: hcnt <= hcnt+1;
	endcase
	oRGB <= (HBLK|VBLK|(hcnt==0)) ? 12'h0 : iRGB;
end

endmodule
