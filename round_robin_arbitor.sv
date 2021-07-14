//////////////////////////////////////////////////////////////
//
//
// Requirement:
//    1.  Equal priority grant
//    2.  Serve all the event before allow the new set of event
//
////////////////////////////////////////////////////////////

module round_robin_arbitor #(parameter N = 8) // Should keep to # in power of 2 for better handling of priority_shift
(
  input  wire  clk,
  input  wire  reset_b,

  input  wire [N-1:0]  request,
  
  output reg [$clog2(N)-1:0]  grant_id,
  output reg grant,
  output wire          stall
);

genvar i;

reg [N-1:0] req_reg;
reg [N-1:0] mask;
reg [$clog2(N)-1:0] priority_shift_count;

//Mux to select qualifier (Before the priority shifting)
wire [N-1:0] request_in_queue = (stall) ? /* synopsys infer_mux_override */ 
                                 req_reg : request;

//Bus for priority rotation
wire [(2*N)-1:0] priority_mask = {request_in_queue, request_in_queue};

//Bus for reverting the priority rotation after arbiter
wire [(2*N)-1:0] arbitor_mask = {mask,mask};

//rotating the priority based on priority_shift (Rotating to right)
wire [N-1:0] qualifer = priority_mask[priority_shift_count +: N];

//Reverting the rotation to get back the original request ID (rotating to left)
wire [N-1:0] grant_mask = arbitor_mask[((2*N-1)-priority_shift_count) -: N];


//Creating one-hot mask bus for grant priority 
assign mask[0] = qualifer[0];
generate
  for (i=1;i<N;i++) begin: GEN_MASK
    assign mask[i] = qualifer[i] & ~{|mask[i-1:0]};
  end
endgenerate

//Always only allow constant value.  Cannot have i-1
//always_comb begin
//  mask[0] = request[0];
//  for (i=1;i<N;i++) mask[i] = qualifer[i] & ~{|mask[i-1:0]};
//end

//Generate the grant output.  
//Update the request queue list.  When req_reg is empty, it then can open for next request
always_ff @(posedge clk or negedge reset_b)
  if (!reset_b) begin 
    req_reg <= 'b0;
    grant_id <= 'b0;
    grant <= 'b0;
    priority_shift_count <= 'b0;
  end else begin 
    req_reg <= request_in_queue ^ grant_mask;
    grant_id <= getIndexFromOneHot(grant_mask);
    grant <= |{grant_mask};

    //Shift when grant and reset to original priority if there is no request
    if ({mask}) priority_shift_count <= priority_shift_count + 1;
    else priority_shift_count <= 0;

  end

//stall will be set when req_reg is not zero
assign stall = |{req_reg};


function [$clog2(N)-1:0] getIndexFromOneHot;
  input [N-1:0] oneHotBus;
  integer i;

  for (i=0;i<N;i++) 
    if (oneHotBus[i]) getIndexFromOneHot = i;
endfunction


endmodule
