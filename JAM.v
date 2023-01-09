module JAM (
input CLK,
input RST,
output  [2:0] W,
output  [2:0] J,
input   [6:0] Cost,
output  [3:0] MatchCount,
output  [9:0] MinCost,
output  Valid );

parameter iniseq = 0, posifind = 1,biggerminfind = 2, newseqfind = 3,ansout = 4;

//***** counter for each state *****

reg [3:0] inicnt;
reg [5:0] posifindcnt;
reg [4:0] biggerminfindcnt;
reg [4:0] newseqcnt;
reg [4:0] newseqoutcnt;

reg [2:0] newseqmid [7:0];
reg [2:0] newseq [7:0];

reg [11:0] mincost;
reg [15:0] seqcnt;

reg [3:0] minseqcnt;
reg [1:0] posifindst;

wire newseqen;
reg [2:0] state , nstate; 

always@(*)begin
	if(RST)
		nstate = iniseq;
	else begin
		case(state)
			iniseq:        nstate = (inicnt == 9)? posifind:iniseq;
			posifind:      nstate = (seqcnt==40319)?ansout:((posifindst == 1)? biggerminfind:posifind);
			biggerminfind: nstate = (biggerminfindcnt == 2)?newseqfind:biggerminfind;
			newseqfind:    nstate = (newseqcnt == 2+1)? posifind:newseqfind;
			ansout:        nstate = ansout;
			default:       nstate = iniseq;
		endcase 
	end
end  

reg [1:0] ansoutcnt;
always@(posedge CLK or posedge RST)begin
	if(RST)
		ansoutcnt <= 0;
	else if(state == ansout)
		ansoutcnt <= ansoutcnt + 1;
	else
		ansoutcnt <= 0;
end

assign Valid = (ansoutcnt == 1)?1:0; 
assign MatchCount = (Valid)?minseqcnt:0;
assign MinCost = (Valid)? mincost:0;

always@(posedge CLK or posedge RST)begin
	if(RST)begin
		state <= iniseq;
	end
	else
		state <= nstate;
end



always@(posedge CLK or posedge RST)begin
	if(RST)
		inicnt <= 0;
	else if(state == iniseq)
		inicnt <= inicnt + 1;
	else
		inicnt <= 0;
end

reg [1:0] ntcostcntst;


reg [7:0] seqlast [7:0];
wire [2:0] wvalue, jvalue;
reg [3:0] ntcostcnt;
assign wvalue = (state == iniseq && inicnt<=7)? inicnt:((ntcostcntst==1)?ntcostcnt:0) ;
assign jvalue = (state == iniseq && inicnt<=7)? inicnt:((ntcostcntst==1)?seqlast[7-ntcostcnt]:0); 

assign W = wvalue;
assign J = jvalue;

reg calen;

reg costen;

always@(posedge CLK or posedge RST)begin
	if(RST)begin
		ntcostcnt<= 0;
		ntcostcntst <= 0;
		calen <= 0;
	end
	else begin
		case(ntcostcntst)
			0:begin
				ntcostcnt <= 0;
				costen <= 0;
				calen <= 0;
				if(newseqen)
					ntcostcntst <= 1;
				else 
					ntcostcntst <= 0;
			end
			1:begin
				if(ntcostcnt == 7)begin
					ntcostcntst <= 0;
					costen <= 1;
				end
				else begin
					ntcostcnt <= ntcostcnt + 1;
					calen <= 1;
				end
			end
		endcase
	end
end



always@(posedge CLK or posedge RST)begin
	if(RST)begin
		seqlast[7] <= 0;
		seqlast[6] <= 0;
		seqlast[5] <= 0;
		seqlast[4] <= 0;
		seqlast[3] <= 0;
		seqlast[2] <= 0;
		seqlast[1] <= 0;
		seqlast[0] <= 0;
	end
	else if(inicnt>=0 && inicnt<=7 && state == iniseq)begin
		seqlast[7-inicnt] <= jvalue;
	end
	else if(newseqcnt == 2)begin
		seqlast[7] <= newseq[7];
		seqlast[6] <= newseq[6];
		seqlast[5] <= newseq[5];
		seqlast[4] <= newseq[4];
		seqlast[3] <= newseq[3];
		seqlast[2] <= newseq[2];
		seqlast[1] <= newseq[1];
		seqlast[0] <= newseq[0];
	end
end

reg costendly ;
always@(posedge CLK or RST)begin
	if(RST)begin
	costendly <= 0;
	end
	else
		costendly <= costen;
		//newseqendly2 <= newseqendly1;
end


reg [11:0] eachcost;
//***** calculate the total cost *****

always@(posedge CLK or posedge RST)begin
	if(RST)
		eachcost <= 0;
	else if(state == iniseq && (inicnt<9 && inicnt>0) || calen ) 
		eachcost <= eachcost + Cost;
	else 
		eachcost <= 0;
end


always@(posedge CLK or posedge RST)begin
	if(RST)begin
		minseqcnt <= 0;
	end
	else if(inicnt == 9 || costendly)begin
		if(eachcost == mincost)
			minseqcnt <= minseqcnt + 1;
		else if(eachcost<mincost)
			minseqcnt <= 1;
	end
end



always@(posedge CLK or posedge RST)begin
	if(RST)begin
		mincost <= 2047;
	end
	else if((inicnt == 9 || costendly))begin
		if(eachcost<mincost)
			mincost<=eachcost;
	end
end


always@(posedge CLK or posedge RST)begin
	if(RST)
		seqcnt<=0;
	else if(costen)
		seqcnt <=  seqcnt + 1;
end 


//***** posifind control *****

always@(posedge CLK or posedge RST)begin
	if(RST)
		posifindcnt <= 0;
	else if(state == posifind)
		posifindcnt <= posifindcnt + 1;
	else
		posifindcnt <= 0;
end

wire [6:0] isbigger;

assign isbigger[6] = (state == posifind)? ((seqlast[6]>seqlast[7])? 1:0):0; 
assign isbigger[5] = (state == posifind)? ((seqlast[5]>seqlast[6])? 1:0):0; 
assign isbigger[4] = (state == posifind)? ((seqlast[4]>seqlast[5])? 1:0):0; 
assign isbigger[3] = (state == posifind)? ((seqlast[3]>seqlast[4])? 1:0):0; 
assign isbigger[2] = (state == posifind)? ((seqlast[2]>seqlast[3])? 1:0):0; 
assign isbigger[1] = (state == posifind)? ((seqlast[1]>seqlast[2])? 1:0):0; 
assign isbigger[0] = (state == posifind)? ((seqlast[0]>seqlast[1])? 1:0):0; 




reg [2:0] posi;

always@(posedge CLK or posedge RST)begin
	if(RST)begin
		posifindst <= 0;
	end
	else if (state == posifind)begin
		case(posifindst)
			0:begin
				if(isbigger[posifindcnt] == 1)
					posifindst = 1;
				else
					posifindst = 0;
			end
			1:begin
				posi <= posifindcnt;
				posifindst <= 2;
			end
			2: posi <= posi;
		endcase
	end
	else 
		posifindst <= 0;
end

always@(posedge CLK or posedge RST)begin
	if(RST)
		biggerminfindcnt <= 0;
	else if(state == biggerminfind)
		biggerminfindcnt <= biggerminfindcnt + 1;
	else	
		biggerminfindcnt <= 0;
end


reg [3:0] comparevec [7:0];

always@(*)begin
	if(RST)begin
		comparevec[7] = 0;
		comparevec[6] = 0;
		comparevec[5] = 0;
		comparevec[4] = 0;
		comparevec[3] = 0;
		comparevec[2] = 0;
		comparevec[1] = 0;
		comparevec[0] = 0;
	end
	else if(state == biggerminfind)begin
		case(posi)
			1: begin
				comparevec[7] = seqlast[posi];
				comparevec[6] = seqlast[posi];
				comparevec[5] = seqlast[posi];
				comparevec[4] = seqlast[posi];
				comparevec[3] = seqlast[posi];
				comparevec[2] = seqlast[posi];
				comparevec[1] = seqlast[posi];
				comparevec[0] = seqlast[0];
			end
			
			2: begin
				comparevec[7] = seqlast[posi];
				comparevec[6] = seqlast[posi];
				comparevec[5] = seqlast[posi];
				comparevec[4] = seqlast[posi];
				comparevec[3] = seqlast[posi];
				comparevec[2] = seqlast[posi];
				comparevec[1] = seqlast[1];
				comparevec[0] = seqlast[0];
			end
			
			3: begin
				comparevec[7] = seqlast[posi];
				comparevec[6] = seqlast[posi];
				comparevec[5] = seqlast[posi];
				comparevec[4] = seqlast[posi];
				comparevec[3] = seqlast[posi];
				comparevec[2] = seqlast[2];
				comparevec[1] = seqlast[1];
				comparevec[0] = seqlast[0];
			end
			4: begin
				comparevec[7] = seqlast[posi];
				comparevec[6] = seqlast[posi];
				comparevec[5] = seqlast[posi];
				comparevec[4] = seqlast[posi];
				comparevec[3] = seqlast[3];
				comparevec[2] = seqlast[2];
				comparevec[1] = seqlast[1];
				comparevec[0] = seqlast[0];
			end
			5: begin
				comparevec[7] = seqlast[posi];
				comparevec[6] = seqlast[posi];
				comparevec[5] = seqlast[posi];
				comparevec[4] = seqlast[4];
				comparevec[3] = seqlast[3];
				comparevec[2] = seqlast[2];
				comparevec[1] = seqlast[1];
				comparevec[0] = seqlast[0];
			end
			6: begin
				comparevec[7] = seqlast[posi];
				comparevec[6] = seqlast[posi];
				comparevec[5] = seqlast[5];
				comparevec[4] = seqlast[4];
				comparevec[3] = seqlast[3];
				comparevec[2] = seqlast[2];
				comparevec[1] = seqlast[1];
				comparevec[0] = seqlast[0];
			end
			7: begin
				comparevec[7] = seqlast[posi];
				comparevec[6] = seqlast[6];
				comparevec[5] = seqlast[5];
				comparevec[4] = seqlast[4];
				comparevec[3] = seqlast[3];
				comparevec[2] = seqlast[2];
				comparevec[1] = seqlast[1];
				comparevec[0] = seqlast[0];
			end
			default:begin
				comparevec[7] = 15;
				comparevec[6] = 15;
				comparevec[5] = 15;
				comparevec[4] = 15;
				comparevec[3] = 15;
				comparevec[2] = 15;
				comparevec[1] = 15;
				comparevec[0] = 15;
			end
		endcase
	end
	else begin
		comparevec[7] = 0;
		comparevec[6] = 0;
		comparevec[5] = 0;
		comparevec[4] = 0;
		comparevec[3] = 0;
		comparevec[2] = 0;
		comparevec[1] = 0;
		comparevec[0] = 0;
	end
end

wire [3:0] biggerseq [7:0];

assign  biggerseq[7] = (comparevec[7]<=seqlast[posi])?15:comparevec[7];
assign  biggerseq[6] = (comparevec[6]<=seqlast[posi])?15:comparevec[6];
assign  biggerseq[5] = (comparevec[5]<=seqlast[posi])?15:comparevec[5];
assign  biggerseq[4] = (comparevec[4]<=seqlast[posi])?15:comparevec[4];
assign  biggerseq[3] = (comparevec[3]<=seqlast[posi])?15:comparevec[3];
assign  biggerseq[2] = (comparevec[2]<=seqlast[posi])?15:comparevec[2];
assign  biggerseq[1] = (comparevec[1]<=seqlast[posi])?15:comparevec[1];
assign  biggerseq[0] = (comparevec[0]<=seqlast[posi])?15:comparevec[0];

reg [3:0] biggerminvalue;
reg [3:0] biggerminposi;


reg [3:0] v0 ,v1, v2,v3,v10 ,v11;
reg [3:0] p0 ,p1, p2,p3,p10 ,p11;

always@(posedge CLK or posedge RST)begin
	if(RST)begin
		v0 <= 0;
		v1 <= 0;
		v2 <= 0;
		v10 <= 0;
		v11 <= 0;
	end
	else if(state == biggerminfind)begin
		if(biggerseq[7]<biggerseq[6])begin
			v0 <= biggerseq[7];
			p0 <= 7;
		end
		else begin
			v0 <= biggerseq[6];
			p0 <= 6;
		end
		if(biggerseq[5]<biggerseq[4])begin
			v1 <= biggerseq[5];
			p1 <= 5;
		end
		else begin
			v1 <= biggerseq[4];
			p1 <= 4;
		end	
		if(biggerseq[3]<biggerseq[2])begin
			v2 <= biggerseq[3];
			p2 = 3;
		end
		else begin
			v2 <= biggerseq[2];
			p2 <= 2;
		end
		if(biggerseq[1]<biggerseq[0])begin
			v3 <= biggerseq[1];
			p3 <= 1;
		end
		else begin
			v3 <= biggerseq[0];
			p3 <= 0;
		end
		if(v0<v1)begin
			v10 <= v0;
			p10 <= p0;
		end
		else begin
			v10 <= v1;
			p10 <= p1;
		end
		if(v2<v3)begin
			v11 <= v2;
			p11 <= p2;
		end
		else begin
			v11 <= v3;
			p11 <= p3;
		end
		if(v10<v11) begin
			biggerminvalue <= v10;
			biggerminposi <= p10;
		end
		else begin
			biggerminvalue <= v11;
			biggerminposi <= p11;
		end
	end
end


always@(posedge CLK or posedge RST)begin
	if(RST)
		newseqcnt <= 0;
	else if(state == newseqfind)
		newseqcnt <= newseqcnt + 1;
	else
		newseqcnt <= 0;
		
end
always@(posedge CLK or posedge RST)begin
	if(RST)begin
		newseqmid[7]<= 0;
		newseqmid[6]<= 0;
		newseqmid[5]<= 0;
		newseqmid[4]<= 0;
		newseqmid[3]<= 0;
		newseqmid[2]<= 0;
		newseqmid[1]<= 0;
		newseqmid[0]<= 0;
	end
	else if (state == newseqfind && newseqcnt <= 2)begin
		newseqmid[7] <= seqlast[7];
		newseqmid[6] <= seqlast[6];
		newseqmid[5] <= seqlast[5];
		newseqmid[4] <= seqlast[4];
		newseqmid[3] <= seqlast[3];
		newseqmid[2] <= seqlast[2];
		newseqmid[1] <= seqlast[1];
		newseqmid[0] <= seqlast[0];
		
		case(posi)
			7:begin
				newseqmid[posi] <= seqlast[biggerminposi];
				newseqmid[biggerminposi] <= seqlast[posi];
				newseq[7] <= newseqmid[7];
				newseq[6] <= newseqmid[0];
				newseq[5] <= newseqmid[1];
				newseq[4] <= newseqmid[2];
				newseq[3] <= newseqmid[3];
				newseq[2] <= newseqmid[4];
				newseq[1] <= newseqmid[5];
				newseq[0] <= newseqmid[6];
			end
			6:begin
				newseqmid[posi] <= seqlast[biggerminposi];
				newseqmid[biggerminposi] <= seqlast[posi];
				newseq[7] <= newseqmid[7];
				newseq[6] <= newseqmid[6];
				newseq[5] <= newseqmid[0];
				newseq[4] <= newseqmid[1];
				newseq[3] <= newseqmid[2];
				newseq[2] <= newseqmid[3];
				newseq[1] <= newseqmid[4];
				newseq[0] <= newseqmid[5];
			end
			5:begin
				newseqmid[posi] <= seqlast[biggerminposi];
				newseqmid[biggerminposi] <= seqlast[posi];
				newseq[7] <= newseqmid[7];
				newseq[6] <= newseqmid[6];
				newseq[5] <= newseqmid[5];
				newseq[4] <= newseqmid[0];
				newseq[3] <= newseqmid[1];
				newseq[2] <= newseqmid[2];
				newseq[1] <= newseqmid[3];
				newseq[0] <= newseqmid[4];
			end
			4:begin
				newseqmid[posi] <= seqlast[biggerminposi];
				newseqmid[biggerminposi] <= seqlast[posi];
				newseq[7] <= newseqmid[7];
				newseq[6] <= newseqmid[6];
				newseq[5] <= newseqmid[5];
				newseq[4] <= newseqmid[4];
				newseq[3] <= newseqmid[0];
				newseq[2] <= newseqmid[1];
				newseq[1] <= newseqmid[2];
				newseq[0] <= newseqmid[3];
			end
			3:begin
				newseqmid[posi] <= seqlast[biggerminposi];
				newseqmid[biggerminposi] <= seqlast[posi];
				newseq[7] <= newseqmid[7];
				newseq[6] <= newseqmid[6];
				newseq[5] <= newseqmid[5];
				newseq[4] <= newseqmid[4];
				newseq[3] <= newseqmid[3];
				newseq[2] <= newseqmid[0];
				newseq[1] <= newseqmid[1];
				newseq[0] <= newseqmid[2];
			end
			2:begin
				newseqmid[posi] <= seqlast[biggerminposi];
				newseqmid[biggerminposi] <= seqlast[posi];
				newseq[7] <= newseqmid[7];
				newseq[6] <= newseqmid[6];
				newseq[5] <= newseqmid[5];
				newseq[4] <= newseqmid[4];
				newseq[3] <= newseqmid[3];
				newseq[2] <= newseqmid[2];
				newseq[1] <= newseqmid[0];
				newseq[0] <= newseqmid[1];
			end
			1:begin
				newseqmid[posi] <= seqlast[biggerminposi];
				newseqmid[biggerminposi] <= seqlast[posi];
				newseq[7] <= newseqmid[7];
				newseq[6] <= newseqmid[6];
				newseq[5] <= newseqmid[5];
				newseq[4] <= newseqmid[4];
				newseq[3] <= newseqmid[3];
				newseq[2] <= newseqmid[2];
				newseq[1] <= newseqmid[1];
				newseq[0] <= newseqmid[0];
			end
			default:begin
				newseqmid[posi] <= seqlast[biggerminposi];
				newseqmid[biggerminposi] <= seqlast[posi];
				newseq[7] <= 0;
				newseq[6] <= 0;
				newseq[5] <= 0;
				newseq[4] <= 0;
				newseq[3] <= 0;
				newseq[2] <= 0;
				newseq[1] <= 0;
				newseq[0] <= 0;
			end
			
		endcase
	end
end



assign newseqen = (newseqcnt == 3)? 1:0;


endmodule


