function run_tARget(model, member, year)

ivtfile = sprintf('/glade/derecho/scratch/tcorrie/regrids/temptARget/ivt.daily.%s.%s.d01_regridded.%s.nc', model, member, year);
islndfile = [];
ivtxname = 'ivtx';
ivtyname = 'ivty';
pixelarea = [];

%sdate = ncreadatt(ivtfile, 'time', 'units');
cal = ncreadatt(ivtfile, 'time', 'calendar');
% Build timedef array
nsteps = ncinfo(ivtfile, 'time').Size;
yr = str2num(year) %str2num(sdate(12:15));
month = 9; %str2num(sdate(17:18));
day = 1; %str2num(sdate(20:21));
hour = 0;
dt = 24;

if strcmp(cal, 'noleap')
    timedef = [nsteps, yr, month, day, hour, dt, 365];
elseif strcmp(cal, '360_day')
    timedef = [nsteps, yr, month, day, hour, dt, 360];
else
    timedef = [nsteps, yr, month, day, hour, dt];
end

undef = -9999;

outfile = sprintf('/glade/derecho/scratch/tcorrie/tARget/outputscratch/ARmask.%s.%s.%s.nc', model, member, year)
pixel_ivtpercentile_limits = sprintf('/glade/derecho/scratch/tcorrie/tARget/pixel_ivt_limits/pixel_ivt_limit_%s_%s.nc', model, member)
global_ivtpercentile_limit = 5; % Doesn't change
universal_ivt_limits = [0,250]; % Anything over 250 always kept
length_limit = 2e6; % Doesn't change. 
lenwidratio_limit = 2; % Doesn't change.
ivtonly = false;
pixel_ivt_filename = sprintf('/glade/derecho/scratch/tcorrie/tARget/pixel_ivt_limits/pixel_ivt_limit_%s_%s.nc', model, member);
target_shapeonly(ivtfile,islndfile,ivtxname,ivtyname,pixelarea,timedef,undef,outfile,pixel_ivtpercentile_limits,global_ivtpercentile_limit,universal_ivt_limits,length_limit,lenwidratio_limit,ivtonly,pixel_ivt_filename);
end