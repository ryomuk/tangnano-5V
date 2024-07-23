// rom.v
// IPL for TangNanoZ80ROM-CPM
// to be included from the top module at the comple

initial
begin
    rom['h0000]=8'hC3; rom['h0001]=8'h80; rom['h0002]=8'h00; rom['h0003]=8'hFF;
    rom['h0080]=8'hED; rom['h0081]=8'h46; rom['h0082]=8'hF3; rom['h0083]=8'h01;
    rom['h0084]=8'h01; rom['h0085]=8'h00; rom['h0086]=8'h21; rom['h0087]=8'h00;
    rom['h0088]=8'h00; rom['h0089]=8'hAF; rom['h008A]=8'hD3; rom['h008B]=8'h0A;
    rom['h008C]=8'h78; rom['h008D]=8'hD3; rom['h008E]=8'h0B; rom['h008F]=8'h79;
    rom['h0090]=8'hD3; rom['h0091]=8'h0C; rom['h0092]=8'h7D; rom['h0093]=8'hD3;
    rom['h0094]=8'h0F; rom['h0095]=8'h7C; rom['h0096]=8'hD3; rom['h0097]=8'h10;
    rom['h0098]=8'hAF; rom['h0099]=8'hD3; rom['h009A]=8'h0D; rom['h009B]=8'hC3;
    rom['h009C]=8'h00; rom['h009D]=8'h00; rom['h009E]=8'h00; rom['h009F]=8'h00;
end
