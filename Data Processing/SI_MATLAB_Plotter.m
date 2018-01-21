%Running this script, either in MATLAB or as deploytool will process RAWCTD
%files in the form of Date,Time,EC,T,P,Depth,Sal,Density.
%The script ignores the Depth, Sal, and Density values derived by the
%MKRZero and calculates depth and salinity separately.

%Three windows will pop up. 1)Downcast profiles of temperature and
%salinity, 2)Time-series of temperature and salinity, 3)Table of converted
%values.

%This data will also be saved to the C: drive in a folder called "OpenCTD_Data" with the date and time as the
%filename. This version has not been tested on Apple hardware, so the
%directory structure should be changed to reflect Apple structuring if
%using Apple hardware.


[filename, pathname] = uigetfile({'*.csv';'*.txt'},'Select OpenCTD Data'); %Open a search window.
filepath=fullfile(pathname,filename);   %Holds location of chosen file.
Data=readtable(filepath,'Delimiter',',','Format','%{MM/dd/uuuu}D %{HH:mm:ss}D %f %f %f %f %f','HeaderLines',3,'ReadVariableNames',false); %Read the csv and create a data array with eight columns.

Date=table2array(Data(:,1));  %Create a Date array.
Time=table2array(Data(:,2));  %Create a Time array.
CnvtDT=@(Date,Time) datetime([Date.Year Date.Month Date.Day Time.Hour Time.Minute Time.Second], 'Format', 'MM.dd.yy HH:mm:ss');
DateTime=CnvtDT(Date,Time);   %Create a DateTime array. 
EC=table2array(Data(:,3));    %Create an EC array in uS/cm.
T=table2array(Data(:,4));     %Create a T array in degC.
P=table2array(Data(:,5));     %Create a P array in millibars.

for L=length(DateTime)  %Assuming sampling rate is 1Hz.
    if L <= 600     %If there is less than ten minutes of data...
        MovValue = 10;      %k=10
    elseif L > 600 && L <= 7200  %If there is less than two hours but more than 10 minutes of data...
        MovValue = 30;      %k=30
    else
        MovValue = 300;     %k-300
    end %Determines the k value for the moving mean based on number of samples taken.
end

%Coefficients for Pressure to Depth Conversion (See AN69 by SeaBird Scientific)
Coeff1=-1.82*10^-15; Coeff2=2.279*10^-10; Coeff3=2.2512*10^-5; Coeff4=9.72659; g=9.806;

%PSS-78 Coefficients (See AN14 by SeaBird Scientific)
A1=2.070*10^-5; A2=-6.370*10^-10; A3=3.989*10^-15;
B1=3.426*10^-2; B2=4.464*10^-1; B3=4.215*10^-1; B4=-3.107*10^-3;
c0=6.766097*10^-1; c1=2.00564*10^-2; c2=1.104259*10^-4; c3=-6.9698*10^-7; c4=1.0031*10^-9;
a0=0.0080; a1=-0.1692; a2=25.3851; a3=14.0941; a4=-7.0261; a5=2.7081;
b0=0.0005; b1=-0.0056; b2=-0.0066; b3=-0.0375; b4=0.0636; b5=-0.0144;
k=0.0162; CStandard=42.914;

latprompt = {'Enter the deployed latitude in decimal degrees.'};  %Open up a prompt for latitude.
dlg_title= 'Latitude';
num_lines = 1;
defaultans = {'45.00'};
latitude = inputdlg(latprompt,dlg_title,num_lines,defaultans);  %Store the user input latitude value.

%Calculating Depth (meters) from Absolute Pressure (See AN69 by SeaBird Scientific)
AtmP = table2array(Data(1,5));
p = (P - AtmP)./100; %Calculate reference pressure in decibars.
x=sin(cell2mat(latitude(1,1))./57.29578);
y=x.*x;
gr = 9.780318 .* (1.0 + (5.2788e-3 + 2.36e-5 .* y) .* y) + 1.092e-6 .* p;
D = ((((-1.82e-15 .* p + 2.279e-10) .* p - 2.2512e-5) .* p + 9.72659) .* p)./gr;


%Salinity Calculations (See AN14 by Seabird Scientific)
R=((EC/1000)/CStandard);
RpNumerator=(A1*p)+(A2*(p).^2)+(A3*(p).^3);
RpDenominator=1+(B1.*T)+(B2.*T.^2)+(B3.*R)+(B4.*T.*R);
Rp=1+(RpNumerator./RpDenominator);
rT=c0+(c1.*T)+(c2.*T.^2)+(c3.*T.^3)+(c4.*T.^4);
RT=R./(rT.*Rp);

%Calculating Salinity
S=(a0+(a1.*RT.^0.5)+(a2.*RT)+(a3.*RT.^1.5)+(a4.*RT.^2)+(a5.*RT.^2.5))+((T-15)./(1+k.*(T-15))).*(b0+(b1.*RT.^0.5)+(b2.*RT)+(b3.*RT.^1.5)+(b4.*RT.^2)+(b5.*RT.^2.5));  %Gives salinity in PSU.

Converted = horzcat(S,T,D);
ind = Converted(:,3)<1;
Filter1=removerows(Converted,'ind',ind); %Cleaned up data array.
[M,I]=max(Filter1(:,3));
Downcast=horzcat(Filter1(1:I,1),Filter1(1:I,2),Filter1(1:I,3));

MovS = movmean(Downcast(:,1),MovValue,'omitnan');  %Calculate the moving mean for salinity.
MovT = movmean(Downcast(:,2),MovValue,'omitnan');  %Calculate the moving mean for temperature.

NAMECNVT=@(Date,Time) datetime([Date.Year Date.Month Date.Day Time.Hour Time.Minute Time.Second], 'Format', 'yyyy-MM-dd_HHmm');
NAME=NAMECNVT(Date,Time);
NEWFILENAME=char(NAME(1,1));

cd C:\
mkdir OpenCTD_Data
cd C:\OpenCTD_Data
mkdir (NEWFILENAME)
cd (NEWFILENAME)

%Create plots of profiles
figure('Name','Profiles','NumberTitle','off');  
subplot(121)  %Temperature Profile
scatter(MovT,-Downcast(:,3),'r.')
hold on
xlabel('Temperature (degC)')
ylabel('Depth (meters)')
title('Temperature Profile')

subplot(122)  %Salinity Profile
scatter(MovS,-Downcast(:,3),'b.')
xlabel('Salinity (PSU)')
ylabel('Depth (meters)')
title('Salinity Profile')
hold off

profname=char(strcat({NEWFILENAME},{'_Profiles'}));
saveas(gcf,profname,'jpeg')

%Create time-series plots.
figure('Name','Time-Series','NumberTitle','off'); 
subplot(311)    %Temperature Time-Series
hold on
plot(DateTime,T,'r')
xlabel('Date and Time')
ylabel('Temperature (degC)')
title('Temperature Time-Series')

subplot(312)
plot(DateTime,S,'b')    %Salinity Time-Series
xlabel('Date and Time')
ylabel('Salinity (PSU)')
title('Salinity Time-Series')

subplot(313)
plot(DateTime,-D,'k')   %Depth Time-Series
xlabel('Date and Time')
ylabel('Depth (meters)')
title('Depth Time-Series')
hold off

seriesname=char(strcat({NEWFILENAME},{'_TimeSeries'}));
saveas(gcf,seriesname,'jpeg')


%Display table of downcast data.
f=figure('Name','Table','NumberTitle','off');
t=uitable(f);
t.Data= Downcast;
t.ColumnName={'Salinity (PSU)','Temperature (degC)','Depth (meters)'};
t.ColumnEditable=false;

name=char(strcat({NEWFILENAME},{'_Processed'},'.csv'));
csvwrite(name,Downcast);
