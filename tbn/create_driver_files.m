clc;
close all;
clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This script was created in Octave 8.4.0
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function write_file (fname,dats)
  fid=fopen(fname,"w");
  fwrite(fid,dats,"int16");
  fclose(fid);
endfunction

%Signal definition
period=2^(16);
tv=((1:period*2))./period;
f1=2;
f2=f1*32;


sig_in1=(f1*pi*tv)+0.0;
sig_in2=(f1*pi*tv)+0.3;
sig_in3=(f1*pi*tv)+0.6;
sig_in4=(f1*pi*tv)+0.9;


sig_in5=(f2*pi*tv)+0.6;
sig_in6=(f2*pi*tv)+0.9;

%ADC and DAC signals must be 16bit signed integers
%ADC signals
%Define any signal you like, here we use 4 slightly phase shifted sine signals
adc_sig0 = sin(sig_in1)*32768;
adc_sig1 = sin(sig_in2)*32768;
adc_sig2 = sin(sig_in3)*32768;
adc_sig3 = sin(sig_in4)*32768;

%DAC signals
%Superimposed a sine on top of another.
dac_sig0 = (sin(sig_in3)+sin(sig_in5)*0.04)*32768;
dac_sig1 = (sin(sig_in4)+sin(sig_in6)*0.04)*32768;

%plot signals
hold on;
stairs(adc_sig0);
stairs(adc_sig1);
stairs(adc_sig2);
stairs(adc_sig3);
stairs(dac_sig0);
stairs(dac_sig1);
hold off;


%write signals to files
path=fileparts(which(mfilename()));
write_file(strcat(path,"/adc_src_ch0.bin"),adc_sig0);
write_file(strcat(path,"/adc_src_ch1.bin"),adc_sig1);
write_file(strcat(path,"/adc_src_ch2.bin"),adc_sig2);
write_file(strcat(path,"/adc_src_ch3.bin"),adc_sig3);
write_file(strcat(path,"/dac_src_ch0.bin"),dac_sig0);
write_file(strcat(path,"/dac_src_ch1.bin"),dac_sig1);


