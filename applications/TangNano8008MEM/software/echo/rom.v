// rom.v
// to be included from the top module at the compile

initial
begin
    mem['h0000]=8'hC0; mem['h0001]=8'h44; mem['h0002]=8'h40; mem['h0003]=8'h00;
    mem['h0004]=8'hFF; mem['h0005]=8'hFF; mem['h0006]=8'hFF; mem['h0007]=8'hFF;
    mem['h0008]=8'h43; mem['h0009]=8'h44; mem['h000A]=8'h43; mem['h000B]=8'h00;
    mem['h000C]=8'hFF; mem['h000D]=8'hFF; mem['h000E]=8'hFF; mem['h000F]=8'hFF;
    mem['h0010]=8'h44; mem['h0011]=8'h40; mem['h0012]=8'h00; mem['h0013]=8'hFF;
    mem['h0014]=8'hFF; mem['h0015]=8'hFF; mem['h0016]=8'hFF; mem['h0017]=8'hFF;
    mem['h0018]=8'h44; mem['h0019]=8'h40; mem['h001A]=8'h00; mem['h001B]=8'hFF;
    mem['h001C]=8'hFF; mem['h001D]=8'hFF; mem['h001E]=8'hFF; mem['h001F]=8'hFF;
    mem['h0020]=8'h44; mem['h0021]=8'h40; mem['h0022]=8'h00; mem['h0023]=8'hFF;
    mem['h0024]=8'hFF; mem['h0025]=8'hFF; mem['h0026]=8'hFF; mem['h0027]=8'hFF;
    mem['h0028]=8'h44; mem['h0029]=8'h40; mem['h002A]=8'h00; mem['h002B]=8'hFF;
    mem['h002C]=8'hFF; mem['h002D]=8'hFF; mem['h002E]=8'hFF; mem['h002F]=8'hFF;
    mem['h0030]=8'h44; mem['h0031]=8'h40; mem['h0032]=8'h00; mem['h0033]=8'hFF;
    mem['h0034]=8'hFF; mem['h0035]=8'hFF; mem['h0036]=8'hFF; mem['h0037]=8'hFF;
    mem['h0038]=8'h06; mem['h0039]=8'h40; mem['h003A]=8'h44; mem['h003B]=8'h43;
    mem['h003C]=8'h00; mem['h003D]=8'hFF; mem['h003E]=8'hFF; mem['h003F]=8'hFF;
    mem['h0040]=8'h44; mem['h0041]=8'h40; mem['h0042]=8'h00; mem['h0043]=8'hC8;
    mem['h0044]=8'h41; mem['h0045]=8'h24; mem['h0046]=8'h04; mem['h0047]=8'h68;
    mem['h0048]=8'h43; mem['h0049]=8'h00; mem['h004A]=8'hC1; mem['h004B]=8'h61;
    mem['h004C]=8'h07; mem['h004D]=8'h41; mem['h004E]=8'h24; mem['h004F]=8'h01;
    mem['h0050]=8'h68; mem['h0051]=8'h4D; mem['h0052]=8'h00; mem['h0053]=8'h43;
    mem['h0054]=8'h07; mem['h0055]=8'h00; mem['h0056]=8'h00; mem['h0057]=8'h00;
end
