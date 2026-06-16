% -*- coding: utf-8 -*-
% Tracking Atmospheric Rivers Globally as Elongated Targets (tARget), Version 4
% Copyright (c) 2015-2024, Bin Guan. All rights reserved.
%
% Usage: target(ivtfile,islndfile,ivtxname,ivtyname,pixelarea,timedef,undef,outfile,pixel_ivtpercentile_limits,global_ivtpercentile_limit,universal_ivt_limits,length_limit,lenwidratio_limit,ivtonly)
%   ivtfile: full path to input netCDF file with two 5-d (nlon x nlat x nlev x ntime x nens) variables containing zonal and meridional IVT in kg/m/s (e.g., 'ivt.nc')
%     - nlev is 1 by definition, but could be re-used for a varying, non-regular dimension, such as forecast step
%     - nens is number of ensemble members
%     - IVT must be 5-d even when nlev=1 and/or nens=1
%     - wildcards can be used to specify multiple files that each spans a segment of time
%   islndfile: full path to input netCDF file with a 2-d (nlon x nlat)---or up to 5-d with trailing singleton dimension(s)---variable named 'islnd' containing 1's over land and 0's over ocean (e.g., 'islnd.nc')
%     - only needed for landfall detection
%     - use [] otherwise
%   ivtxname: variable name for zonal IVT (e.g., 'ivtx') 
%   ivtyname: variable name for meridional IVT (e.g., 'ivty')
%   pixelarea: pixel area in m^2
%     - only needed for non-geographic projection
%     - use [] otherwise
%   timedef: temporal grid
%     - only needed when temporal grid is not present inside ivtfile or not on regular calendar
%         - regular calendar: [ntime,year,month,day,hour,dtime], indicating ntime steps, starting from year-month-day hour:00, at dtime-hour intervals (e.g., [100000,1948,2,1,0,6])
%         - 365-day calendar: [...,365]
%     - use [] otherwise
%   undef: missing value flag (e.g., -9999)
%     - only needed when missing values are present but not properly flagged inside ivtfile
%     - use [] otherwise
%   outfile: full path to output netCDF file (e.g., 'out.nc')
%     - 5-d (nlon x nlat x nlev x ntime x nens) variables: AR shape, axis, transect, and (for landfalling ARs) landfall location
%     - 4-d (nlon x nlev x ntime x nens) variables: attributes of individual AR (year, month, day, hour, length, width, centroid longitude, centroid latitude, etc.)
%     - pixel_ivt_limit.nc (same folder as outfile; produced only when pixel_ivtpercentile_limits is numeric): 5-d (nlon x nlat x nlev x 12 x nens) variable(s) named 'ivt1', 'ivt2', ... containing IVT limit in kg/m/s
%   pixel_ivtpercentile_limits: IVT percentile limits
%     - when numeric: [i1,i2,i3,...], for i1th, i2th (optional), i3th (optional), ... percentiles (e.g., [85,87.5,90,92.5,95])
%     - when non-numeric: full path to input netCDF file with 5-d (nlon x nlat x nlev|1 x 12 x nens|1) variable(s) named 'ivt1', 'ivt2', ... containing IVT limit in kg/m/s (e.g., 'ivt85-95.nc')
%   global_ivtpercentile_limit: IVT globally-constant but seasonally-varying limits based on global_ivtpercentile_limit'th percentile of IVT values corresponding to pixel_ivtpercentile_limits (e.g., 5)
%   universal_ivt_limits: IVT fixed limits [l1,l2] in kg/m/s, indicating IVT below l1 is never retained, and IVT above l2 (optional) is always retained (e.g., [100,500])
%   length_limit: length limit in m (e.g., 2e6)
%   lenwidratio_limit: length/width ratio limit (e.g., 2)
%
% Example 1:
%   target('ivt.nc','islnd.nc','ivtx','ivty',[],[],[],'out.nc',85,5,0,2e6,2) 
% Example 2: as Example 1 but with non-geographic projection and pixel area of 250km x 250km
%   target('ivt.nc','islnd.nc','ivtx','ivty',250e3^2,[],[],'out.nc',85,5,0,2e6,2) 
% Example 3: as Example 1 but reading pre-calculated IVT 85th percentile values from existing file
%   target('ivt.nc','islnd.nc','ivtx','ivty',[],[],[],'out.nc','ivt85.nc',5,0,2e6,2) 
%
% References:
% - Guan, B., and D. E. Waliser (2015), Detection of atmospheric rivers:
%   Evaluation and application of an algorithm for global studies,
%   J. Geophys. Res. Atmos., 120, 12514-12535, doi:10.1002/2015JD024257.
% - Guan, B., D. E. Waliser, and F. M. Ralph (2018), An inter-comparison
%   between reanalysis and dropsonde observations of the total water vapor
%   transport in individual atmospheric rivers, J. Hydrometeorol., 19,
%   321-337, doi:10.1175/JHM-D-17-0114.1.
%   Guan, B., and D. E. Waliser (2019), Tracking atmospheric rivers globally:
% - Spatial distributions and temporal evolution of life cycle characteristics,
%   J. Geophys. Res. Atmos., 124, 12523-12552, doi:10.1029/2019JD031205.
% - Guan, B., and D. E. Waliser (2024), A regionally refined quarter-degree
%   global atmospheric rivers database based on ERA5, Sci. Data, accepted.

function target_shapeonly(ivtfile,islndfile,ivtxname,ivtyname,pixelarea,timedef,undef,outfile,pixel_ivtpercentile_limits,global_ivtpercentile_limit,universal_ivt_limits,length_limit,lenwidratio_limit,ivtonly,pixel_ivt_filename)

if nargin<15 || isempty(pixel_ivt_filename)
    pixel_ivt_filename='pixel_ivt_limit.nc';
end


tARget_version='4';
disp(['Tracking Atmospheric Rivers Globally as Elongated Targets (tARget), Version ',tARget_version]);
disp('Copyright (c) 2015-2024, Bin Guan. All rights reserved.');
disp(' ');
disp('References:');
disp('- Guan, B., and D. E. Waliser (2015), Detection of atmospheric rivers:');
disp('  Evaluation and application of an algorithm for global studies,');
disp('  J. Geophys. Res. Atmos., 120, 12514-12535, doi:10.1002/2015JD024257.');
disp('- Guan, B., D. E. Waliser, and F. M. Ralph (2018), An inter-comparison');
disp('  between reanalysis and dropsonde observations of the total water vapor');
disp('  transport in individual atmospheric rivers, J. Hydrometeorol., 19,');
disp('  321-337, doi:10.1175/JHM-D-17-0114.1.');
disp('- Guan, B., and D. E. Waliser (2019), Tracking atmospheric rivers globally:');
disp('  Spatial distributions and temporal evolution of life cycle characteristics,');
disp('  J. Geophys. Res. Atmos., 124, 12523-12552, doi:10.1029/2019JD031205.');
disp('- Guan, B., and D. E. Waliser (2024), A regionally refined quarter-degree');
disp('  global atmospheric rivers database based on ERA5, Sci. Data, accepted.');
disp(' ');

fprintf(1,'Obtaining licenses ');
while true
fprintf(1,'.');
[status1,~]=license('checkout','image_toolbox');
[status2,~]=license('checkout','map_toolbox');
[status3,~]=license('checkout','statistics_toolbox');
if status1 && status2 && status3
break;
else
pause(60);
end
end
fprintf(1,' done.\n');
fprintf(1,'Program started at %s.\n',datestr(now)); tic;
disp(' ');

[~,cmdout]=system(['ls -1 ',ivtfile]);
ivtfiles=textscan(cmdout,'%s','delimiter','\n');
ivtfiles=ivtfiles{1};
nfile=numel(ivtfiles);
[outdir,~,~]=fileparts(outfile);

if ~ischar(pixel_ivtpercentile_limits) && ~issorted(pixel_ivtpercentile_limits)
disp('[ERROR] IVT percentile limits must be in ascending order. Program stopped.');
return
end
if ~issorted(universal_ivt_limits)
disp('[ERROR] IVT universal limits must be in ascending order. Program stopped.');
return
end
if numel(universal_ivt_limits)==1
universal_ivt_limits(2)=Inf;
end

earth_radius=6371e3;
landmass_area_limit=(2.5*distance(0,0,0,1,earth_radius))^2;
object_area_limit=length_limit*100e3;
object_ivty_limit=0.25;
object_ivtdirspread_limit=67.5;
%track_speed_limit=150e3/3600;
matrix_numel_limit=1e9;
%freshness=struct('genesis',1,'continuation',2,'termination',3,'geneterm',0);

ivtx_info=ncinfo(ivtfiles{1},ivtxname);
dimensions={ivtx_info.Dimensions.Name};
if numel(dimensions)==5
dims='xyzte';
elseif numel(dimensions)==3
dims='xyt';
else
error('[ERROR] IVT must be in a 5-d (nlon x nlat x nlev x ntime x nens) or 3-d (nlon x nlat x ntime) variable. Program stopped.');
end
if strcmp(dims,'xyzte')
lonname=dimensions{1};
latname=dimensions{2};
levname=dimensions{3};
timename=dimensions{4};
ensname=dimensions{5};
else
lonname=dimensions{1};
latname=dimensions{2};
levname='lev';
timename=dimensions{3};
ensname='ens';
end

lon=double(ncread(ivtfiles{1},lonname));
lat=double(ncread(ivtfiles{1},latname));
if isvector(lat) && range(diff(lat))==0
nlon=numel(lon);
nlat=numel(lat);
dlon=lon(2)-lon(1);
dlat=abs(lat(2)-lat(1));
lon=repmat(lon,[1,nlat]);
lat=repmat(lat',[nlon,1]);
pixelarea=reshape(areaquad(lat(:)-dlat/2,lon(:)-dlon/2,lat(:)+dlat/2,lon(:)+dlon/2,earth_radius),[nlon,nlat]);
is_geographic=1;
is_global_lon=nlon*dlon==360;
is_global_lat=nlat*dlat>=180;
is_even_lat=1;
elseif isvector(lat) && range(diff(lat))~=0
nlon=numel(lon);
nlat=numel(lat);
dlon=lon(2)-lon(1);
dlat=abs(nanmean(diff(lat)));
lon=repmat(lon,[1,nlat]);
lat=repmat(lat',[nlon,1]);
pixelarea=reshape(areaquad(lat(:)-dlat/2,lon(:)-dlon/2,lat(:)+dlat/2,lon(:)+dlon/2,earth_radius),[nlon,nlat]);
is_geographic=1;
is_global_lon=nlon*dlon==360;
is_global_lat=nlat*dlat>=180;
is_even_lat=0;
else
pixelarea=ones(size(lon))*pixelarea;
is_geographic=0;
is_global_lon=0;
is_global_lat=0;
is_even_lat=0;
end
[nrow,ncol]=size(lon);

if strcmp(dims,'xyzte')
lev=double(ncread(ivtfiles{1},levname));
ens=double(ncread(ivtfiles{1},ensname));
else
lev=0;
ens=1;
end
nlev=numel(lev);
nens=numel(ens);

fprintf(1,'Constructing time axis ...');
if ~isempty(timedef)
ntime=timedef(1);
year=NaN(ntime,1); month=NaN(ntime,1); day=NaN(ntime,1); hour=NaN(ntime,1);
year(1)=timedef(2);
month(1)=timedef(3);
day(1)=timedef(4);
hour(1)=timedef(5);
dtime=timedef(6);
if isnan(dtime)
time=0;
else
time=(0:dtime:((ntime-1)*dtime))*3600;
end
if mod(ntime,1)~=0
disp('[ERROR] Number of time steps must be integer. Program stopped.');
return
end
if mod(hour(1),1)~=0
disp('[ERROR] Starting hour must be integer. Program stopped.');
return
end
if mod(dtime,1)~=0
disp('[ERROR] Time interval must be integer. Program stopped.');
return
end
if numel(timedef)==6
cal='';
else
if timedef(7)==365
cal='365_day';
elseif timedef(7)==360
cal='360_day';
else
disp('[ERROR] Unsupported calendar. Program stopped.');
return
end
end
thisyear=year(1);
thismonth=month(1);
thisday=day(1);
thishour=hour(1);
for tcnt=2:ntime
thishour=thishour+dtime;
if thishour>=24
thisday=thisday+floor(thishour/24);
thishour=mod(thishour,24);
end
if strcmp(cal, '360_day')
numdaythismonth=[30,30,30,30,30,30,30,30,30,30,30,30];
elseif isempty(cal) && ((~mod(thisyear,4) && mod(thisyear,100)) || ~mod(thisyear,400))
numdaythismonth=[31,29,31,30,31,30,31,31,30,31,30,31];
else
numdaythismonth=[31,28,31,30,31,30,31,31,30,31,30,31];
end
if thisday>numdaythismonth(thismonth)
thismonth=thismonth+1;
thisday=1;
end
if thismonth>12
thisyear=thisyear+1;
thismonth=1;
end
year(tcnt)=thisyear;
month(tcnt)=thismonth;
day(tcnt)=thisday;
hour(tcnt)=thishour;
end
year_month_day_hour_minute_second=[year,month,day,hour,zeros(size(hour)),zeros(size(hour))];
else
time_info=ncinfo(ivtfiles{1},timename);
if any(strcmp({time_info.Attributes.Name},'calendar'))
cal=time_info.Attributes(strcmp({time_info.Attributes.Name},'calendar')).Value;
if ~(strcmp(cal,'gregorian') || strcmp(cal,'standard'))
disp('[ERROR] Unsupported netCDF calendar. Program stopped.');
return
end
else
cal='';
end
year_month_day_hour_minute_second=cell(1,nfile);
for fcnt=1:nfile
ivtfile=ivtfiles{fcnt};
time_thisfile=double(ncread(ivtfile,timename));
time_unit=ncreadatt(ivtfile,timename,'units');
time_unit=textscan(time_unit,'%s','delimiter',' ');
time_unit=time_unit{1};
time_unit_interval=time_unit{1};
time_unit_base=[time_unit{3},' ',time_unit{4}];
if strcmp(time_unit_interval,'days')
factor=1;
elseif strcmp(time_unit_interval,'hours') 
factor=24;
elseif strcmp(time_unit_interval,'minutes') 
factor=1440;
elseif strcmp(time_unit_interval,'seconds') 
factor=86400;
else
disp('[ERROR] Unsupported netCDF time units. Program stopped.');
return
end
year_month_day_hour_minute_second{fcnt}=datevec(datenum(time_unit_base)+time_thisfile/factor);
end
year_month_day_hour_minute_second=cat(1,year_month_day_hour_minute_second{:});
ntime=size(year_month_day_hour_minute_second,1);
year=year_month_day_hour_minute_second(:,1);
month=year_month_day_hour_minute_second(:,2);
day=year_month_day_hour_minute_second(:,3);
hour=year_month_day_hour_minute_second(:,4);
time=(datenum(year_month_day_hour_minute_second)-datenum(year_month_day_hour_minute_second(1,:)))*24*3600;
end
fprintf(1,' done.\n');
fprintf(1,'%i time steps to process: %4i.%02i.%02i %02iZ to %4i.%02i.%02i %02iZ.\n',[ntime,year(1),month(1),day(1),hour(1),year(end),month(end),day(end),hour(end)]);

if ~isempty(islndfile)
islnd=ncread(islndfile,'islnd');
islnd=islnd==1;
islnd=bwlabel(islnd);
if is_geographic && is_global_lon
islnd=rejoin_object(islnd);
end
for ocnt=unique(islnd(islnd~=0))'
if nansum(pixelarea(islnd==ocnt))<landmass_area_limit
islnd(islnd==ocnt)=0;
end
end
islnd=islnd~=0;
islnd_unfilled=islnd;
ishole=imfill(bwmorph(islnd,'bridge'),'holes')-bwmorph(islnd,'bridge');
ishole=bwlabel(ishole);
for ocnt=unique(ishole(ishole~=0))'
if nansum(pixelarea(ishole==ocnt))<landmass_area_limit*9
ishole(ishole==ocnt)=0;
end
end
ishole=ishole~=0;
islnd=islnd | ishole;
islnd=imfill(islnd,'holes');
if is_geographic && is_global_lon
islnd=[islnd(round(nrow/2)+1:end,:);islnd(1:round(nrow/2),:)];
ishole=imfill(bwmorph(islnd,'bridge'),'holes')-bwmorph(islnd,'bridge');
ishole=bwlabel(ishole);
for ocnt=unique(ishole(ishole~=0))'
if nansum(pixelarea(ishole==ocnt))<landmass_area_limit*9
ishole(ishole==ocnt)=0;
end
end
ishole=ishole~=0;
islnd=islnd | ishole;
islnd=imfill(islnd,'holes');
islnd=[islnd(end-(round(nrow/2)-1):end,:);islnd(1:end-round(nrow/2),:)];
end
iscst=bwperim(islnd);
if is_geographic && is_global_lon
islnd2=[islnd(round(nrow/2)+1:end,:);islnd(1:round(nrow/2),:)];
iscst2=bwperim(islnd2);
iscst2=[iscst2(end-(round(nrow/2)-1):end,:);iscst2(1:end-round(nrow/2),:)];
iscst=iscst & iscst2;
end
if is_geographic && is_global_lat
iscst(:,1)=0;
end
islnd=islnd_unfilled;
iscst=iscst & islnd;
islnd=double(islnd);
iscst=double(iscst);
else
islnd=zeros(nrow,ncol);
iscst=zeros(nrow,ncol);
end

if ~ischar(pixel_ivtpercentile_limits)
fprintf(1,'%i file(s) in queue: %s to %s.\n',nfile,ivtfiles{1},ivtfiles{end});
fprintf(1,'Preprocessing ');
num_limit=numel(pixel_ivtpercentile_limits);
nblock=ceil(nrow*ncol*nlev*ntime*nens/matrix_numel_limit);
dim1_nblock=ceil(sqrt(nblock*(nrow/ncol)));
dim2_nblock=ceil(sqrt(nblock/(nrow/ncol)));
dim1_step=ceil(nrow/dim1_nblock);
dim2_step=ceil(ncol/dim2_nblock);
dim1_start=1:dim1_step:nrow;
dim1_end=dim1_start+dim1_step-1;
dim1_end(dim1_end>nrow)=nrow;
dim1_step=dim1_end-dim1_start+1;
dim1_nblock=numel(dim1_start);
dim2_start=1:dim2_step:ncol;
dim2_end=dim2_start+dim2_step-1;
dim2_end(dim2_end>ncol)=ncol;
dim2_step=dim2_end-dim2_start+1;
dim2_nblock=numel(dim2_start);
pixel_ivt_limit=NaN(nrow,ncol,nlev,num_limit,nens,12);
for dim1_bcnt=1:dim1_nblock
for dim2_bcnt=1:dim2_nblock
fprintf(1,'.');
ivt=[];
for fcnt=1:nfile
ivtfile=ivtfiles{fcnt};
if strcmp(dims,'xyzte')
ivtx=ncread(ivtfile,ivtxname,[dim1_start(dim1_bcnt),dim2_start(dim2_bcnt),1,1,1],[dim1_step(dim1_bcnt),dim2_step(dim2_bcnt),inf,inf,inf]);
ivty=ncread(ivtfile,ivtyname,[dim1_start(dim1_bcnt),dim2_start(dim2_bcnt),1,1,1],[dim1_step(dim1_bcnt),dim2_step(dim2_bcnt),inf,inf,inf]);
else
ivtx=ncread(ivtfile,ivtxname,[dim1_start(dim1_bcnt),dim2_start(dim2_bcnt),1],[dim1_step(dim1_bcnt),dim2_step(dim2_bcnt),inf]);
ivty=ncread(ivtfile,ivtyname,[dim1_start(dim1_bcnt),dim2_start(dim2_bcnt),1],[dim1_step(dim1_bcnt),dim2_step(dim2_bcnt),inf]);
end
if ~isempty(undef)
ivtx(ivtx==undef)=NaN;
ivty(ivty==undef)=NaN;
end
ivt=cat(4,ivt,sqrt(ivtx.^2+ivty.^2));
end
pixel_ivt_limit(dim1_start(dim1_bcnt):dim1_end(dim1_bcnt),dim2_start(dim2_bcnt):dim2_end(dim2_bcnt),:,:,:,11)=prctile(ivt(:,:,:,month>= 9 | month<=1,:),pixel_ivtpercentile_limits,4);
pixel_ivt_limit(dim1_start(dim1_bcnt):dim1_end(dim1_bcnt),dim2_start(dim2_bcnt):dim2_end(dim2_bcnt),:,:,:,12)=prctile(ivt(:,:,:,month>=10 | month<=2,:),pixel_ivtpercentile_limits,4);
pixel_ivt_limit(dim1_start(dim1_bcnt):dim1_end(dim1_bcnt),dim2_start(dim2_bcnt):dim2_end(dim2_bcnt),:,:,:, 1)=prctile(ivt(:,:,:,month>=11 | month<=3,:),pixel_ivtpercentile_limits,4);
pixel_ivt_limit(dim1_start(dim1_bcnt):dim1_end(dim1_bcnt),dim2_start(dim2_bcnt):dim2_end(dim2_bcnt),:,:,:, 2)=prctile(ivt(:,:,:,month>=12 | month<=4,:),pixel_ivtpercentile_limits,4);
for month_cnt=3:10
pixel_ivt_limit(dim1_start(dim1_bcnt):dim1_end(dim1_bcnt),dim2_start(dim2_bcnt):dim2_end(dim2_bcnt),:,:,:,month_cnt)=prctile(ivt(:,:,:,month>=month_cnt-2 & month<=month_cnt+2,:),pixel_ivtpercentile_limits,4);
end
end
end
pixel_ivt_limit=permute(pixel_ivt_limit,[1,2,3,6,5,4]);
fprintf(1,' done.\n');
pixel_ivt_limit_outfile=fullfile(outdir,pixel_ivt_filename);
if exist(pixel_ivt_limit_outfile,'file')
delete(pixel_ivt_limit_outfile);
end
%for lcnt=1:num_limit
%nccreate(pixel_ivt_limit_outfile,['ivt',num2str(lcnt)],'dimensions',{'lon',nrow,'lat',ncol,'lev',nlev,'time',12,'ens',nens},'chunksize',[nrow,ncol,1,1,1],'datatype','double','format','netcdf4','deflatelevel',9);
%end
if is_geographic
nccreate(pixel_ivt_limit_outfile,'lon','dimensions',{'lon',nrow});
nccreate(pixel_ivt_limit_outfile,'lat','dimensions',{'lat',ncol});
else
nccreate(pixel_ivt_limit_outfile,'lon','dimensions',{'lon',nrow,'lat',ncol});
nccreate(pixel_ivt_limit_outfile,'lat','dimensions',{'lon',nrow,'lat',ncol});
end
nccreate(pixel_ivt_limit_outfile,'lev','dimensions',{'lev',nlev});
nccreate(pixel_ivt_limit_outfile,'time','dimensions',{'time',12});
nccreate(pixel_ivt_limit_outfile,'ens','dimensions',{'ens',nens});
for lcnt=1:num_limit
nccreate(pixel_ivt_limit_outfile,['ivt',num2str(lcnt)],'dimensions',{'lon',nrow,'lat',ncol,'lev',nlev,'time',12,'ens',nens},'chunksize',[nrow,ncol,1,1,1],'datatype','double','format','netcdf4','deflatelevel',9);
ncwrite(pixel_ivt_limit_outfile,['ivt',num2str(lcnt)],pixel_ivt_limit(:,:,:,:,:,lcnt));
end
if is_geographic
ncwrite(pixel_ivt_limit_outfile,'lon',lon(:,1));
ncwrite(pixel_ivt_limit_outfile,'lat',lat(1,:));
else
ncwrite(pixel_ivt_limit_outfile,'lon',lon);
ncwrite(pixel_ivt_limit_outfile,'lat',lat);
end
ncwrite(pixel_ivt_limit_outfile,'lev',lev);
ncwrite(pixel_ivt_limit_outfile,'time',(1:12)-1);
ncwrite(pixel_ivt_limit_outfile,'ens',ens);
for lcnt=1:num_limit
ncwriteatt(pixel_ivt_limit_outfile,['ivt',num2str(lcnt)],'long_name',sprintf('IVT %gth Percentile',pixel_ivtpercentile_limits(lcnt)));
ncwriteatt(pixel_ivt_limit_outfile,['ivt',num2str(lcnt)],'units','kg m^-1 s^-1');
end
ncwriteatt(pixel_ivt_limit_outfile,'lon','units','degrees_east');
ncwriteatt(pixel_ivt_limit_outfile,'lat','units','degrees_north');
ncwriteatt(pixel_ivt_limit_outfile,'lev','units','m');
ncwriteatt(pixel_ivt_limit_outfile,'time','units','months since 0001-01-01 00:00:00');
ncwriteatt(pixel_ivt_limit_outfile,'ens','axis','e');
if(~isempty(cal))
ncwriteatt(pixel_ivt_limit_outfile,'time','calendar',cal);
end
else
file_info=ncinfo(pixel_ivtpercentile_limits);
sizes={file_info.Variables.Size};
num_limit=numel(find(cellfun(@numel,sizes)==5));
if num_limit==0
disp('[ERROR] IVT percentile limits must be in a 5-d (nlon x nlat x nlev x 12 x nens) variable. Program stopped.');
return
end
pixel_ivt_limit=NaN(nrow,ncol,numel(ncread(pixel_ivtpercentile_limits,'lev')),12,numel(ncread(pixel_ivtpercentile_limits,'ens')),num_limit);
for lcnt=1:num_limit
pixel_ivt_limit(:,:,:,:,:,lcnt)=ncread(pixel_ivtpercentile_limits,['ivt',num2str(lcnt)]);
end
end

if ivtonly
disp('ivtonly set to true. Stopping tARget.m');
return
end

num_season=12;
pixel_ivt_limit_reshaped=reshape(pixel_ivt_limit,[nrow*ncol,nlev,num_season,nens,num_limit]);
pixelarea_reshaped=repmat(pixelarea(:),[1,nlev,num_season,nens,num_limit]);
global_ivt_limit_reshaped=nan(size(pixel_ivt_limit_reshaped));
try
global_ivt_limit_reshaped(find(lat<=0),:,:,:,:)=repmat(prctilew(pixel_ivt_limit_reshaped(find(lat<=0),:,:,:,:),pixelarea_reshaped(find(lat<=0),:,:,:,:),global_ivtpercentile_limit),[numel(find(lat<=0)),1,1,1,1]);
catch
disp("No data on the equator or SH.");
end
global_ivt_limit_reshaped(find(lat>=0),:,:,:,:)=repmat(prctilew(pixel_ivt_limit_reshaped(find(lat>=0),:,:,:,:),pixelarea_reshaped(find(lat>=0),:,:,:,:),global_ivtpercentile_limit),[numel(find(lat>=0)),1,1,1,1]);
if ~isempty(find(lat<0)) && ~isempty(find(lat==0)) && ~isempty(find(lat>0))
global_ivt_limit_reshaped(find(lat==0),:,:,:,:)=repmat((min(global_ivt_limit_reshaped,[],1)+max(global_ivt_limit_reshaped,[],1))/2,[numel(find(lat==0)),1,1,1,1]);
end
global_ivt_limit=reshape(global_ivt_limit_reshaped,[nrow,ncol,nlev,num_season,nens,num_limit]);
pixel_ivt_limit=max(pixel_ivt_limit,global_ivt_limit);

fprintf(1,'%i file(s) in queue: %s to %s.\n',nfile,ivtfiles{1},ivtfiles{end});
tcnt=1;
if exist(outfile,'file')
tcnt_restart=ncreadatt(outfile,'time','ntime_written')+1;
else
tcnt_restart=1;
end
tic_mainloop=tic;

for fcnt=1:nfile
ivtfile=ivtfiles{fcnt};
time_thisfile=ncread(ivtfile,timename);
ntime_thisfile=numel(time_thisfile);

for tcnt_thisfile=1:ntime_thisfile
if tcnt>=tcnt_restart
    fprintf(1,'Processing time step %i of %i ...',tcnt,ntime);
    tic_thisstep=tic;
else
    fprintf(1,'Skipping time step %i of %i ...\n',tcnt,ntime);
tcnt=tcnt+1;
continue
end

for ecnt=1:nens

for zcnt=1:nlev

if strcmp(dims,'xyzte')
ivtx=ncread(ivtfile,ivtxname,[1,1,zcnt,tcnt_thisfile,ecnt],[inf,inf,1,1,1]);
ivty=ncread(ivtfile,ivtyname,[1,1,zcnt,tcnt_thisfile,ecnt],[inf,inf,1,1,1]);
else
ivtx=ncread(ivtfile,ivtxname,[1,1,tcnt_thisfile],[inf,inf,1]);
ivty=ncread(ivtfile,ivtyname,[1,1,tcnt_thisfile],[inf,inf,1]);
end
if ~isempty(undef)
ivtx(ivtx==undef)=NaN;
ivty(ivty==undef)=NaN;
end

ivt=sqrt(ivtx.^2+ivty.^2);
ivt_reduced=ivt;

outer_perim_ivt=bwperim(~isnan(ivt));
outer_perim_box=bwperim(ones([nrow,ncol]));
is_tight_outer_perim=isequal(outer_perim_ivt,outer_perim_box);

num_object=zeros(7,num_limit);

lcnt=1;
if size(pixel_ivt_limit,3)==nlev
zcnt_for_pixel_ivt_limit=zcnt;
else
zcnt_for_pixel_ivt_limit=1;
end
if size(pixel_ivt_limit,5)==nens
ecnt_for_pixel_ivt_limit=ecnt;
else
ecnt_for_pixel_ivt_limit=1;
end
if lcnt==1
shape_map=ivt_reduced>=min(max(pixel_ivt_limit(:,:,zcnt_for_pixel_ivt_limit,month(tcnt),ecnt_for_pixel_ivt_limit,lcnt),universal_ivt_limits(1)),universal_ivt_limits(2));
else
shape_map=ivt_reduced>=max(pixel_ivt_limit(:,:,zcnt_for_pixel_ivt_limit,month(tcnt),ecnt_for_pixel_ivt_limit,lcnt),universal_ivt_limits(1));
end
shape_map=imfill(shape_map,'holes');
if is_geographic && is_global_lon
shape_map=[shape_map(round(nrow/2)+1:end,:);shape_map(1:round(nrow/2),:)];
shape_map=imfill(shape_map,'holes');
shape_map=[shape_map(end-(round(nrow/2)-1):end,:);shape_map(1:end-round(nrow/2),:)];
end
shape_map=bwlabel(shape_map);
if is_geographic && is_global_lon
shape_map=rejoin_object(shape_map);
end

for ocnt=unique(shape_map(shape_map~=0))'
if nansum(pixelarea(shape_map==ocnt))<object_area_limit
shape_map(shape_map==ocnt)=0;
end
end

whirl_map=zeros(nrow,ncol);
ivtdir_quadrant=round(atan_in_azimuth(ivty,ivtx)/90)*90;
for ocnt=unique(shape_map(shape_map~=0))'
if all(ismember(0:90:270,ivtdir_quadrant(shape_map==ocnt)))
[axis_idx,iswhirl]=object_axis(lon,lat,pixelarea,ivt,ivtx,ivty,shape_map==ocnt,is_geographic,is_global_lon,earth_radius);
if iswhirl
eye_lon=mod(rad2deg(angle(nansum(exp(1i*deg2rad(lon(axis_idx))).*pixelarea(axis_idx))/nansum(pixelarea(axis_idx)))),360);
eye_lat=nansum(lat(axis_idx).*pixelarea(axis_idx))/nansum(pixelarea(axis_idx));
azimuth_to_ringdot1=azimuth(eye_lat,eye_lon,lat(axis_idx(1)),lon(axis_idx(1)),earth_radius);
azimuth_to_ringdot2=azimuth(eye_lat,eye_lon,lat(axis_idx(1+round(numel(axis_idx)/4))),lon(axis_idx(1+round(numel(axis_idx)/4))),earth_radius);
degree_diff=mod(azimuth_to_ringdot2-azimuth_to_ringdot1,360);
degree_diff(degree_diff>180)=degree_diff(degree_diff>180)-360;
clock_direction=sign(degree_diff);
azimuth_to_shape=azimuth(eye_lat,eye_lon,lat(shape_map==ocnt),lon(shape_map==ocnt),earth_radius);
degree_diff=mod(atan_in_azimuth(ivty(shape_map==ocnt),ivtx(shape_map==ocnt))-azimuth_to_shape,360);
degree_diff(degree_diff>180)=degree_diff(degree_diff>180)-360;
shape_idx=find(shape_map==ocnt);
whirl_idx=shape_idx(degree_diff>clock_direction*90-45 & degree_diff<clock_direction*90+45);
whirl_map(whirl_idx)=1;
whirl_map=imfill(whirl_map,'holes');
if is_geographic && is_global_lon
whirl_map=[whirl_map(round(nrow/2)+1:end,:);whirl_map(1:round(nrow/2),:)];
whirl_map=imfill(whirl_map,'holes');
whirl_map=[whirl_map(end-(round(nrow/2)-1):end,:);whirl_map(1:end-round(nrow/2),:)];
end
end
end
end
ivt_reduced(whirl_map>0)=NaN;

for lcnt=1:num_limit
if lcnt>1
ivt_reduced(shape_map>0)=NaN;
end

if size(pixel_ivt_limit,3)==nlev
zcnt_for_pixel_ivt_limit=zcnt;
else
zcnt_for_pixel_ivt_limit=1;
end
if size(pixel_ivt_limit,5)==nens
ecnt_for_pixel_ivt_limit=ecnt;
else
ecnt_for_pixel_ivt_limit=1;
end
if lcnt==1
shape_map=ivt_reduced>=min(max(pixel_ivt_limit(:,:,zcnt_for_pixel_ivt_limit,month(tcnt),ecnt_for_pixel_ivt_limit,lcnt),universal_ivt_limits(1)),universal_ivt_limits(2));
else
shape_map=ivt_reduced>=max(pixel_ivt_limit(:,:,zcnt_for_pixel_ivt_limit,month(tcnt),ecnt_for_pixel_ivt_limit,lcnt),universal_ivt_limits(1));
end
shape_map=imfill(shape_map,'holes');
if is_geographic && is_global_lon
shape_map=[shape_map(round(nrow/2)+1:end,:);shape_map(1:round(nrow/2),:)];
shape_map=imfill(shape_map,'holes');
shape_map=[shape_map(end-(round(nrow/2)-1):end,:);shape_map(1:end-round(nrow/2),:)];
end
shape_map=bwlabel(shape_map);
if is_geographic && is_global_lon
shape_map=rejoin_object(shape_map);
end
num_object(1,lcnt)=numel(unique(shape_map(shape_map~=0)));

for ocnt=unique(shape_map(shape_map~=0))'
if nansum(pixelarea(shape_map==ocnt))<object_area_limit
shape_map(shape_map==ocnt)=0;
end
end
num_object(2,lcnt)=numel(unique(shape_map(shape_map~=0)));

shape_map=imfill(shape_map,'holes');
if is_geographic && is_global_lon
shape_map=[shape_map(round(nrow/2)+1:end,:);shape_map(1:round(nrow/2),:)];
shape_map=imfill(shape_map,'holes');
shape_map=[shape_map(end-(round(nrow/2)-1):end,:);shape_map(1:end-round(nrow/2),:)];
end

object_ivtx_allocnt=cell(1,num_object(1,lcnt));
object_ivty_allocnt=cell(1,num_object(1,lcnt));
object_ivtdir_allocnt=cell(1,num_object(1,lcnt));
%object_ivtdirspread_allocnt=cell(1,num_object(1,lcnt));
for ocnt=unique(shape_map(shape_map~=0))'
object_ivtx=nansum(ivtx(shape_map==ocnt).*pixelarea(shape_map==ocnt))/nansum(pixelarea(shape_map==ocnt));
object_ivty=nansum(ivty(shape_map==ocnt).*pixelarea(shape_map==ocnt))/nansum(pixelarea(shape_map==ocnt));
object_ivtdir=atan_in_azimuth(object_ivty,object_ivtx);
degree_diff=mod(atan_in_azimuth(ivty,ivtx)-object_ivtdir,360); degree_diff(degree_diff>180)=360-degree_diff(degree_diff>180);
object_ivtdirspread=sqrt(nansum(degree_diff(shape_map==ocnt).^2.*pixelarea(shape_map==ocnt).*ivt(shape_map==ocnt))/nansum(pixelarea(shape_map==ocnt).*ivt(shape_map==ocnt)));
if object_ivtdirspread>object_ivtdirspread_limit
shape_map(shape_map==ocnt)=0;
end
object_ivtx_allocnt{ocnt}=object_ivtx;
object_ivty_allocnt{ocnt}=object_ivty;
object_ivtdir_allocnt{ocnt}=object_ivtdir;
%object_ivtdirspread_allocnt{ocnt}=object_ivtdirspread;
end
num_object(3,lcnt)=numel(unique(shape_map(shape_map~=0)));

axis_map=zeros(nrow,ncol);
axis_idx_allocnt=cell(1,num_object(1,lcnt));
axis_lon_allocnt=cell(1,num_object(1,lcnt));
axis_lat_allocnt=cell(1,num_object(1,lcnt));
for ocnt=unique(shape_map(shape_map~=0))'
axis_idx=object_axis(lon,lat,pixelarea,ivt,ivtx,ivty,shape_map==ocnt,is_geographic,is_global_lon,earth_radius);
if ~(is_geographic && is_global_lon && is_global_lat && is_tight_outer_perim)
axis_idx(outer_perim_ivt(axis_idx))=[];
end
if numel(axis_idx)>nrow
axis_idx=axis_idx(round(1:(numel(axis_idx)-1)/(nrow-1):end));
end
axis_lon=mod(smoothdata(rad2deg(unwrap(deg2rad(lon(axis_idx)))),'sgolay'),360);
axis_lat=smoothdata(lat(axis_idx),'sgolay');
if numel(axis_idx)>=2
axis_map(axis_idx)=ocnt+(1:numel(axis_idx))/1e5;
else
shape_map(shape_map==ocnt)=0;
end
axis_idx_allocnt{ocnt}=axis_idx;
axis_lon_allocnt{ocnt}=axis_lon;
axis_lat_allocnt{ocnt}=axis_lat;
end
num_object(4,lcnt)=numel(unique(shape_map(shape_map~=0)));

%centroid_lon_allocnt=cell(1,num_object(1,lcnt));
%centroid_lat_allocnt=cell(1,num_object(1,lcnt));
for ocnt=unique(shape_map(shape_map~=0))'
is_straddling_equator=min(lat(shape_map==ocnt))*max(lat(shape_map==ocnt))<0;
%centroid_lon=mod(rad2deg(angle(nansum(exp(1i*deg2rad(lon(shape_map==ocnt))).*pixelarea(shape_map==ocnt).*ivt(shape_map==ocnt))/nansum(pixelarea(shape_map==ocnt).*ivt(shape_map==ocnt)))),360);
centroid_lat=nansum(lat(shape_map==ocnt).*pixelarea(shape_map==ocnt).*ivt(shape_map==ocnt))/nansum(pixelarea(shape_map==ocnt).*ivt(shape_map==ocnt));
axis_ivtx=ivtx(axis_idx_allocnt{ocnt});
axis_ivty=ivty(axis_idx_allocnt{ocnt});
axis_ivt=sqrt(axis_ivtx.^2+axis_ivty.^2);
if centroid_lat<0
axis_ivty=-axis_ivty;
end
poleward_axis_lon=axis_lon_allocnt{ocnt}; poleward_axis_lon(axis_ivty<object_ivty_limit*axis_ivt)=nan;
poleward_axis_lat=axis_lat_allocnt{ocnt}; poleward_axis_lat(axis_ivty<object_ivty_limit*axis_ivt)=nan;
inter_pixel_distance=distance(poleward_axis_lat(1:end-1),poleward_axis_lon(1:end-1),poleward_axis_lat(2:end),poleward_axis_lon(2:end),earth_radius);
poleward_axis_length=nansum(inter_pixel_distance);
if is_straddling_equator || poleward_axis_length<0.5*length_limit
shape_map(shape_map==ocnt)=0;
end
%centroid_lon_allocnt{ocnt}=centroid_lon;
%centroid_lat_allocnt{ocnt}=centroid_lat;
end
num_object(5,lcnt)=numel(unique(shape_map(shape_map~=0)));

object_length_allocnt=cell(1,num_object(1,lcnt));
object_width_allocnt=cell(1,num_object(1,lcnt));
for ocnt=unique(shape_map(shape_map~=0))'
inter_pixel_distance=distance(axis_lat_allocnt{ocnt}(1:end-1),axis_lon_allocnt{ocnt}(1:end-1),axis_lat_allocnt{ocnt}(2:end),axis_lon_allocnt{ocnt}(2:end),earth_radius);
object_length=nansum(inter_pixel_distance);
object_length=object_length/numel(inter_pixel_distance)*(numel(inter_pixel_distance)+1);
object_width=nansum(pixelarea(shape_map==ocnt))/object_length;
if object_length<length_limit || object_length/object_width<lenwidratio_limit
shape_map(shape_map==ocnt)=0;
end
object_length_allocnt{ocnt}=object_length;
object_width_allocnt{ocnt}=object_width;
end
num_object(6,lcnt)=numel(unique(shape_map(shape_map~=0)));

%lfloc_map=zeros(nrow,ncol);
for ocnt=unique(shape_map(shape_map~=0))'
axis_idx=axis_idx_allocnt{ocnt};
intersect_idx=find(shape_map==ocnt & iscst & ~(ivtx==0 & ivty==0));
if ~isempty(intersect_idx)
intersect_ivt_direction=atan_in_azimuth(ivty(intersect_idx),ivtx(intersect_idx));
[intersect_leeward_lat,intersect_leeward_lon]=reckon(lat(intersect_idx),lon(intersect_idx),sqrt(max(pixelarea(:))),intersect_ivt_direction,earth_radius,'degrees');
intersect_leeward_idx=lonlat2idx(intersect_leeward_lon,intersect_leeward_lat,lon,lat,pixelarea,is_geographic,is_even_lat,earth_radius);
intersect_leeward_islnd=zeros(size(intersect_leeward_idx));
intersect_leeward_islnd(~isnan(intersect_leeward_idx))=islnd(intersect_leeward_idx(~isnan(intersect_leeward_idx)));
[intersect_windward_lat,intersect_windward_lon]=reckon(lat(intersect_idx),lon(intersect_idx),sqrt(max(pixelarea(:))),intersect_ivt_direction-180,earth_radius,'degrees');
intersect_windward_idx=lonlat2idx(intersect_windward_lon,intersect_windward_lat,lon,lat,pixelarea,is_geographic,is_even_lat,earth_radius);
intersect_windward_isocn=zeros(size(intersect_windward_idx));
intersect_windward_isocn(~isnan(intersect_windward_idx))=~islnd(intersect_windward_idx(~isnan(intersect_windward_idx)));
%[intersect_leeward2_lat,intersect_leeward2_lon]=reckon(lat(intersect_idx),lon(intersect_idx),sqrt(max(pixelarea(:))),object_ivtdir_allocnt{ocnt},earth_radius,'degrees');
intersect_leeward2_idx=lonlat2idx(intersect_leeward2_lon,intersect_leeward2_lat,lon,lat,pixelarea,is_geographic,is_even_lat,earth_radius);
intersect_leeward2_islnd=zeros(size(intersect_leeward2_idx));
intersect_leeward2_islnd(~isnan(intersect_leeward2_idx))=islnd(intersect_leeward2_idx(~isnan(intersect_leeward2_idx)));
%[intersect_windward2_lat,intersect_windward2_lon]=reckon(lat(intersect_idx),lon(intersect_idx),sqrt(max(pixelarea(:))),object_ivtdir_allocnt{ocnt}-180,earth_radius,'degrees');
intersect_windward2_idx=lonlat2idx(intersect_windward2_lon,intersect_windward2_lat,lon,lat,pixelarea,is_geographic,is_even_lat,earth_radius);
intersect_windward2_isocn=zeros(size(intersect_windward2_idx));
intersect_windward2_isocn(~isnan(intersect_windward2_idx))=~islnd(intersect_windward2_idx(~isnan(intersect_windward2_idx)));
tailside_length=nan(size(intersect_idx));
for icnt=1:numel(intersect_idx)
intersect_to_axis_azimuth=azimuth(lat(intersect_idx(icnt)),lon(intersect_idx(icnt)),lat(axis_idx),lon(axis_idx),earth_radius);
%degree_diff=mod(intersect_to_axis_azimuth-object_ivtdir_allocnt{ocnt},360); degree_diff(degree_diff>180)=360-degree_diff(degree_diff>180);
tailside_axis_idx=axis_idx(degree_diff>90);
inter_pixel_distance=distance(lat(tailside_axis_idx(1:end-1)),lon(tailside_axis_idx(1:end-1)),lat(tailside_axis_idx(2:end)),lon(tailside_axis_idx(2:end)),earth_radius);
inter_pixel_distance(inter_pixel_distance>sqrt(8)*sqrt(max(pixelarea(:))))=nan;
inter_pixel_distance(~((~islnd(tailside_axis_idx(1:end-1)) & ~islnd(tailside_axis_idx(2:end))) | (~islnd(tailside_axis_idx(1:end-1)) & iscst(tailside_axis_idx(2:end))) | (iscst(tailside_axis_idx(1:end-1)) & ~islnd(tailside_axis_idx(2:end)))))=nan;
tailside_length(icnt)=nansum(inter_pixel_distance);
end
intersect_idx=intersect_idx(intersect_leeward_islnd & intersect_windward_isocn & intersect_leeward2_islnd & intersect_windward2_isocn & tailside_length>0.5*length_limit);
if ~isempty(intersect_idx)
[~,max_loc]=max(ivt(intersect_idx));
%lfloc_map(intersect_idx(max_loc))=ocnt;
end
end
end
%num_object(7,lcnt)=numel(unique(lfloc_map(lfloc_map~=0)));

%tnsct_map=zeros(nrow,ncol);
%object_width2_allocnt=cell(1,num_object(1,lcnt));
%tnsct_tivt_allocnt=cell(1,num_object(1,lcnt));
% for ocnt=unique(shape_map(shape_map~=0))'
% %search_radius=object_length_allocnt{ocnt};
% %num_point=numel(axis_idx_allocnt{ocnt})*5;
% %if centroid_lat_allocnt{ocnt}<0
% %[tnsct_lat_half1,tnsct_lon_half1]=track1(centroid_lat_allocnt{ocnt},centroid_lon_allocnt{ocnt},object_ivtdir_allocnt{ocnt}+90,search_radius,earth_radius,'degrees',num_point);
% %[tnsct_lat_half2,tnsct_lon_half2]=track1(centroid_lat_allocnt{ocnt},centroid_lon_allocnt{ocnt},object_ivtdir_allocnt{ocnt}-90,search_radius,earth_radius,'degrees',num_point);
% %else
% %[tnsct_lat_half1,tnsct_lon_half1]=track1(centroid_lat_allocnt{ocnt},centroid_lon_allocnt{ocnt},object_ivtdir_allocnt{ocnt}-90,search_radius,earth_radius,'degrees',num_point);
% %[tnsct_lat_half2,tnsct_lon_half2]=track1(centroid_lat_allocnt{ocnt},centroid_lon_allocnt{ocnt},object_ivtdir_allocnt{ocnt}+90,search_radius,earth_radius,'degrees',num_point);
% %end
% %tnsct_lon=[flip(tnsct_lon_half1);tnsct_lon_half2];
% %tnsct_lat=[flip(tnsct_lat_half1);tnsct_lat_half2];
% %tnsct_idx=lonlat2idx(tnsct_lon,tnsct_lat,lon,lat,pixelarea,is_geographic,is_even_lat,earth_radius);
% %tnsct_idx(isnan(tnsct_idx))=[];
% %tnsct_idx=unique(tnsct_idx,'stable');
% %dummy_map=zeros(nrow,ncol);
% %dummy_map(tnsct_idx)=1;
% %dummy_map(shape_map~=ocnt)=0;
% % if any(dummy_map(:))
% % dummy_map=bwmorph(imfill(dummy_map,'holes'),'thin',inf);
% % dummy_map=bwlabel(dummy_map);
% % if is_geographic && is_global_lon
% % dummy_map=rejoin_object(dummy_map);
% % end
% % ivt_masked=-ones(nrow,ncol);
% % ivt_masked(dummy_map~=0)=ivt(dummy_map~=0);
% % dummy_map(dummy_map~=dummy_map(find(ivt_masked==max(ivt_masked(:)),1,'first')))=0;
% % dummy_idx=find(dummy_map~=0);
% % tnsct_idx(~ismember(tnsct_idx,dummy_idx))=[];
% % else
% % tnsct_idx=nan;
% % end
% if numel(tnsct_idx)>=2
% object_width2=distance(lat(tnsct_idx(1)),lon(tnsct_idx(1)),lat(tnsct_idx(end)),lon(tnsct_idx(end)),earth_radius);
% object_width2=object_width2/(numel(tnsct_idx)-1)*numel(tnsct_idx);
% tnsct_ivtx=nansum(ivtx(tnsct_idx).*pixelarea(tnsct_idx))/nansum(pixelarea(tnsct_idx));
% tnsct_ivty=nansum(ivty(tnsct_idx).*pixelarea(tnsct_idx))/nansum(pixelarea(tnsct_idx));
% tnsct_ivtdir=atan_in_azimuth(tnsct_ivty,tnsct_ivtx);
% %tnsct_tivt=sqrt(tnsct_ivtx^2+tnsct_ivty^2)*abs(cos(deg2rad(object_ivtdir_allocnt{ocnt}-tnsct_ivtdir)))*object_width2;
% %tnsct_map(tnsct_idx)=ocnt+(1:numel(tnsct_idx))/1e5;
% else
% object_width2=nan;
% tnsct_tivt=nan;
% end
% %object_width2_allocnt{ocnt}=object_width2;
% %tnsct_tivt_allocnt{ocnt}=tnsct_tivt;
% end

if lcnt==1
shape_map_alllcnt=cell(1,num_limit);
%axis_map_alllcnt=cell(1,num_limit);
%tnsct_map_alllcnt=cell(1,num_limit);
%lfloc_map_alllcnt=cell(1,num_limit);
%object_ivtx_allocnt_alllcnt=cell(1,num_limit);
%object_ivty_allocnt_alllcnt=cell(1,num_limit);
%object_ivtdir_allocnt_alllcnt=cell(1,num_limit);
%object_ivtdirspread_allocnt_alllcnt=cell(1,num_limit);
%centroid_lon_allocnt_alllcnt=cell(1,num_limit);
%centroid_lat_allocnt_alllcnt=cell(1,num_limit);
%object_length_allocnt_alllcnt=cell(1,num_limit);
%object_width_allocnt_alllcnt=cell(1,num_limit);
%object_width2_allocnt_alllcnt=cell(1,num_limit);
%tnsct_tivt_allocnt_alllcnt=cell(1,num_limit);
%axis_idx_allocnt_alllcnt=cell(1,num_limit);
%axis_lon_allocnt_alllcnt=cell(1,num_limit);
%axis_lat_allocnt_alllcnt=cell(1,num_limit);
end
shape_map_alllcnt{lcnt}=shape_map;
%axis_map_alllcnt{lcnt}=axis_map;
%tnsct_map_alllcnt{lcnt}=tnsct_map;
%lfloc_map_alllcnt{lcnt}=lfloc_map;
%object_ivtx_allocnt_alllcnt{lcnt}=object_ivtx_allocnt;
%object_ivty_allocnt_alllcnt{lcnt}=object_ivty_allocnt;
%object_ivtdir_allocnt_alllcnt{lcnt}=object_ivtdir_allocnt;
%object_ivtdirspread_allocnt_alllcnt{lcnt}=object_ivtdirspread_allocnt;
%centroid_lon_allocnt_alllcnt{lcnt}=centroid_lon_allocnt;
%centroid_lat_allocnt_alllcnt{lcnt}=centroid_lat_allocnt;
%object_length_allocnt_alllcnt{lcnt}=object_length_allocnt;
%object_width_allocnt_alllcnt{lcnt}=object_width_allocnt;
%object_width2_allocnt_alllcnt{lcnt}=object_width2_allocnt;
%tnsct_tivt_allocnt_alllcnt{lcnt}=tnsct_tivt_allocnt;
%axis_idx_allocnt_alllcnt{lcnt}=axis_idx_allocnt;
%axis_lon_allocnt_alllcnt{lcnt}=axis_lon_allocnt;
%axis_lat_allocnt_alllcnt{lcnt}=axis_lat_allocnt;

end

for lcnt=1:num_limit
%unique_val=unique(shape_map_alllcnt{lcnt}(shape_map_alllcnt{lcnt}~=0));
%axis_map_alllcnt{lcnt}(~ismember(floor(axis_map_alllcnt{lcnt}),unique_val))=0;
%tnsct_map_alllcnt{lcnt}(~ismember(floor(tnsct_map_alllcnt{lcnt}),unique_val))=0;
%lfloc_map_alllcnt{lcnt}(~ismember(lfloc_map_alllcnt{lcnt},unique_val))=0;
end

cumu_num_object=num_object(1,1);
for lcnt=2:num_limit
shape_map_alllcnt{lcnt}(shape_map_alllcnt{lcnt}~=0)=shape_map_alllcnt{lcnt}(shape_map_alllcnt{lcnt}~=0)+cumu_num_object;
%axis_map_alllcnt{lcnt}(axis_map_alllcnt{lcnt}~=0)=axis_map_alllcnt{lcnt}(axis_map_alllcnt{lcnt}~=0)+cumu_num_object;
%tnsct_map_alllcnt{lcnt}(tnsct_map_alllcnt{lcnt}~=0)=tnsct_map_alllcnt{lcnt}(tnsct_map_alllcnt{lcnt}~=0)+cumu_num_object;
%lfloc_map_alllcnt{lcnt}(lfloc_map_alllcnt{lcnt}~=0)=lfloc_map_alllcnt{lcnt}(lfloc_map_alllcnt{lcnt}~=0)+cumu_num_object;
cumu_num_object=cumu_num_object+num_object(1,lcnt);
end
shape_map=nansum(cat(3,shape_map_alllcnt{:}),3);
%axis_map=nansum(cat(3,axis_map_alllcnt{:}),3);
%tnsct_map=nansum(cat(3,tnsct_map_alllcnt{:}),3);
%lfloc_map=nansum(cat(3,lfloc_map_alllcnt{:}),3);
%object_ivtx_allocnt=cat(2,object_ivtx_allocnt_alllcnt{:});
%object_ivty_allocnt=cat(2,object_ivty_allocnt_alllcnt{:});
%object_ivtdir_allocnt=cat(2,object_ivtdir_allocnt_alllcnt{:});
%object_ivtdirspread_allocnt=cat(2,object_ivtdirspread_allocnt_alllcnt{:});
%centroid_lon_allocnt=cat(2,centroid_lon_allocnt_alllcnt{:});
%centroid_lat_allocnt=cat(2,centroid_lat_allocnt_alllcnt{:});
%object_length_allocnt=cat(2,object_length_allocnt_alllcnt{:});
%object_width_allocnt=cat(2,object_width_allocnt_alllcnt{:});
%object_width2_allocnt=cat(2,object_width2_allocnt_alllcnt{:});
%tnsct_tivt_allocnt=cat(2,tnsct_tivt_allocnt_alllcnt{:});
%axis_idx_allocnt=cat(2,axis_idx_allocnt_alllcnt{:});
%axis_lon_allocnt=cat(2,axis_lon_allocnt_alllcnt{:});
%axis_lat_allocnt=cat(2,axis_lat_allocnt_alllcnt{:});

unique_val=unique(shape_map(shape_map~=0));
%unique_val=[unique_val(ismember(unique_val,lfloc_map));unique_val(~ismember(unique_val,lfloc_map))];
shape_map_tmp=zeros(size(shape_map));
%axis_map_tmp=zeros(size(axis_map));
%tnsct_map_tmp=zeros(size(tnsct_map));
%lfloc_map_tmp=zeros(size(lfloc_map));
for ocnt=1:numel(unique_val)
shape_map_tmp(shape_map==unique_val(ocnt))=ocnt;
%axis_map_tmp(floor(axis_map)==unique_val(ocnt))=axis_map(floor(axis_map)==unique_val(ocnt))-floor(axis_map(floor(axis_map)==unique_val(ocnt)))+ocnt;
%tnsct_map_tmp(floor(tnsct_map)==unique_val(ocnt))=tnsct_map(floor(tnsct_map)==unique_val(ocnt))-floor(tnsct_map(floor(tnsct_map)==unique_val(ocnt)))+ocnt;
%lfloc_map_tmp(lfloc_map==unique_val(ocnt))=ocnt;
end
shape_map=shape_map_tmp;
%axis_map=axis_map_tmp;
%tnsct_map=tnsct_map_tmp;
%lfloc_map=lfloc_map_tmp;
%object_ivtx_allocnt=object_ivtx_allocnt(unique_val);
%object_ivty_allocnt=object_ivty_allocnt(unique_val);
%object_ivtdir_allocnt=object_ivtdir_allocnt(unique_val);
%object_ivtdirspread_allocnt=object_ivtdirspread_allocnt(unique_val);
%centroid_lon_allocnt=centroid_lon_allocnt(unique_val);
%centroid_lat_allocnt=centroid_lat_allocnt(unique_val);
%object_length_allocnt=object_length_allocnt(unique_val);
%object_width_allocnt=object_width_allocnt(unique_val);
%object_width2_allocnt=object_width2_allocnt(unique_val);
%tnsct_tivt_allocnt=tnsct_tivt_allocnt(unique_val);
%axis_idx_allocnt=axis_idx_allocnt(unique_val);
%axis_lon_allocnt=axis_lon_allocnt(unique_val);
%axis_lat_allocnt=axis_lat_allocnt(unique_val);
unique_val=unique(shape_map(shape_map~=0));

%year_thismap=cell(1,numel(unique_val));
%month_thismap=cell(1,numel(unique_val));
%day_thismap=cell(1,numel(unique_val));
%hour_thismap=cell(1,numel(unique_val));
shape_allocnt=cell(1,numel(unique_val));
%axistail_lon_allocnt=cell(1,numel(unique_val));
%axistail_lat_allocnt=cell(1,numel(unique_val));
%axishead_lon_allocnt=cell(1,numel(unique_val));
%axishead_lat_allocnt=cell(1,numel(unique_val));
%lfloc_lon_allocnt=cell(1,numel(unique_val));
%lfloc_lat_allocnt=cell(1,numel(unique_val));
%lfloc_ivtx_allocnt=cell(1,numel(unique_val));
%lfloc_ivty_allocnt=cell(1,numel(unique_val));
%lfloc_ivtdir_allocnt=cell(1,numel(unique_val));
for ocnt=1:numel(unique_val)
%year_thismap{ocnt}=year(tcnt);
%month_thismap{ocnt}=month(tcnt);
%day_thismap{ocnt}=day(tcnt);
%hour_thismap{ocnt}=hour(tcnt);
shape_allocnt{ocnt}=ocnt;
%axistail_lon_allocnt{ocnt}=mod(lon(axis_map==min(axis_map(floor(axis_map)==ocnt))),360);
%axistail_lat_allocnt{ocnt}=lat(axis_map==min(axis_map(floor(axis_map)==ocnt)));
%axishead_lon_allocnt{ocnt}=mod(lon(axis_map==max(axis_map(floor(axis_map)==ocnt))),360);
%axishead_lat_allocnt{ocnt}=lat(axis_map==max(axis_map(floor(axis_map)==ocnt)));
%lfloc_lon_allocnt{ocnt}=mod(lon(lfloc_map==ocnt),360);
%lfloc_lat_allocnt{ocnt}=lat(lfloc_map==ocnt);
%lfloc_ivtx_allocnt{ocnt}=ivtx(lfloc_map==ocnt);
%lfloc_ivty_allocnt{ocnt}=ivty(lfloc_map==ocnt);
%lfloc_ivtdir_allocnt{ocnt}=atan_in_azimuth(lfloc_ivty_allocnt{ocnt},lfloc_ivtx_allocnt{ocnt});
% if isempty(lfloc_lon_allocnt{ocnt})
% %lfloc_lon_allocnt{ocnt}=NaN;
% lfloc_lat_allocnt{ocnt}=NaN;
% lfloc_ivtx_allocnt{ocnt}=NaN;
% lfloc_ivty_allocnt{ocnt}=NaN;
% lfloc_ivtdir_allocnt{ocnt}=NaN;
% end
end

%track_id_map=zeros(nrow,ncol);
%track_status_map=zeros(nrow,ncol);
%track_instvelx_allocnt=num2cell(NaN(1,numel(unique_val)));
%track_instvely_allocnt=num2cell(NaN(1,numel(unique_val)));
if tcnt==1
%kcnt=0;
for val=unique_val'
%kcnt=kcnt+1;
%separation=0;
%merger=0;
%freshness_here=freshness.genesis;
%track_id_map(shape_map==val)=str2double(sprintf('%04i%02i%02i%02i%02i',year_thismap{val},month_thismap{val},day_thismap{val},hour_thismap{val},shape_allocnt{val}));
%track_status_map(shape_map==val)=separation*100+merger*10+freshness_here;
end
else
%kid_earlier=ncread(outfile,'kid',[1,zcnt,tcnt-1,ecnt],[inf,1,1,1])'; kid_earlier(isnan(kid_earlier))=[];
%track_tcntfrom_allocnt_earlier=num2cell(ones(size(kid_earlier)));
%for t=tcnt-2:-1:1
%kid_thisstep=ncread(outfile,'kid',[1,zcnt,t,ecnt],[inf,1,1,1])'; kid_thisstep(isnan(kid_thisstep))=[];
%track_tcntfrom_allocnt_earlier(~ismember(kid_earlier,kid_thisstep) & [track_tcntfrom_allocnt_earlier{:}]==1)={t+1};
%if all(~ismember(kid_earlier,kid_thisstep))
%break;
%end
%end
%track_ntime_max=tcnt-min([track_tcntfrom_allocnt_earlier{:}]);
%kcnt=ncread(outfile,'kcnt',[zcnt,tcnt-1,ecnt],[1,1,1]);
%if tcnt_thisfile>=2
%if strcmp(dims,'xyzte')
%ivtx_earlier=ncread(ivtfile,ivtxname,[1,1,zcnt,tcnt_thisfile-1,ecnt],[inf,inf,1,1,1]);
%ivty_earlier=ncread(ivtfile,ivtyname,[1,1,zcnt,tcnt_thisfile-1,ecnt],[inf,inf,1,1,1]);
%else
%ivtx_earlier=ncread(ivtfile,ivtxname,[1,1,tcnt_thisfile-1],[inf,inf,1]);
%ivty_earlier=ncread(ivtfile,ivtyname,[1,1,tcnt_thisfile-1],[inf,inf,1]);
%end
%else
%ivtfile_earlier=ivtfiles{fcnt-1};
%time_earlierfile=ncread(ivtfile_earlier,timename);
%ntime_earlierfile=numel(time_earlierfile);
%ivtx_earlier=ncread(ivtfile_earlier,ivtxname,[1,1,zcnt,ntime_earlierfile,ecnt],[inf,inf,1,1,1]);
%ivty_earlier=ncread(ivtfile_earlier,ivtyname,[1,1,zcnt,ntime_earlierfile,ecnt],[inf,inf,1,1,1]);
%end
%ivt_earlier=sqrt(ivtx_earlier.^2+ivty_earlier.^2);
%shape_map_earlier=ncread(outfile,'shapemap',[1,1,zcnt,tcnt-1,ecnt],[inf,inf,1,1,1]);
%shape_map_earlier(isnan(shape_map_earlier))=0;
%track_id_map_earlier=ncread(outfile,'kidmap',[1,1,zcnt,tcnt-1,ecnt],[inf,inf,1,1,1]);
%track_id_map_earlier(isnan(track_id_map_earlier))=0;
%track_status_map_earlier=ncread(outfile,'kstatusmap',[1,1,zcnt,tcnt-1,ecnt],[inf,inf,1,1,1]);
%track_status_map_earlier(isnan(track_status_map_earlier))=0;
%track_status_allocnt_earlier=ncread(outfile,'kstatus',[1,zcnt,tcnt-1,ecnt],[inf,1,1,1])';
%track_status_allocnt_earlier=num2cell(track_status_allocnt_earlier);
%shape_map_earlier_reduced=shape_map_earlier;
%shape_map_reduced=shape_map;
% while true
% %shape_2maps=bwlabeln(cat(3,shape_map_earlier_reduced,shape_map_reduced));
% if is_geographic && is_global_lon
% shape_2maps=rejoin_object(shape_2maps);
% end
% %pairing_val_earlier_pending=[];
% pairing_val_pending=[];
% for ocnt=unique(shape_2maps(shape_2maps~=0))'
% %pairing_val_earlier=unique(shape_map_earlier_reduced(shape_2maps(:,:,1)==ocnt));
% %pairing_val=unique(shape_map_reduced(shape_2maps(:,:,2)==ocnt));
% % if numel(pairing_val_earlier)==0 && numel(pairing_val)==1
% % separation=0;
% % merger=0;
% % paired_val_earlier=[];
% % paired_val=[];
% % unpaired_val_earlier=[];
% % unpaired_val=pairing_val;
% % elseif numel(pairing_val_earlier)==1 && numel(pairing_val)==0
% % separation=0;
% % merger=0;
% % paired_val_earlier=[];
% % paired_val=[];
% % unpaired_val_earlier=pairing_val_earlier;
% % unpaired_val=[];
% % elseif numel(pairing_val_earlier)==1 && numel(pairing_val)==1
% % separation=0;
% % merger=0;
% % mask_earlier=shape_map_earlier==pairing_val_earlier;
% % mask=shape_map; mask(~ismember(mask,pairing_val))=0;
% % paired_val_earlier=pairing_val_earlier;
% % [inter_step_disp,paired_val]=displace_object(lon,lat,pixelarea, ...
% % ivt_earlier,mask_earlier, ...
% % track_speed_limit*(time(tcnt)-time(tcnt-1)), ...
% % ivt,mask, ...
% % is_geographic,is_global_lon,is_even_lat,earth_radius);
% % unpaired_val_earlier=[];
% % unpaired_val=[];
% % elseif numel(pairing_val_earlier)==1 && numel(pairing_val)>=2
% % separation=1;
% % merger=0;
% % mask_earlier=shape_map_earlier==pairing_val_earlier;
% % mask=shape_map; mask(~ismember(mask,pairing_val))=0;
% % paired_val_earlier=pairing_val_earlier;
% % [inter_step_disp,paired_val]=displace_object(lon,lat,pixelarea, ...
% % ivt_earlier,mask_earlier, ...
% % track_speed_limit*(time(tcnt)-time(tcnt-1)), ...
% % ivt,mask, ...
% % is_geographic,is_global_lon,is_even_lat,earth_radius);
% % unpaired_val_earlier=[];
% % unpaired_val=pairing_val(pairing_val~=paired_val);
% % elseif numel(pairing_val_earlier)>=2 && numel(pairing_val)==1
% % separation=0;
% % merger=1;
% % mask_earlier=shape_map_earlier; mask_earlier(~ismember(mask_earlier,pairing_val_earlier))=0;
% % mask=shape_map==pairing_val;
% % [inter_step_disp,paired_val_earlier]=displace_object(lon,lat,pixelarea, ...
% % ivt,mask, ...
% % track_speed_limit*(time(tcnt)-time(tcnt-1)), ...
% % ivt_earlier,mask_earlier, ...
% % is_geographic,is_global_lon,is_even_lat,earth_radius); inter_step_disp=-inter_step_disp;
% % paired_val=pairing_val;
% % unpaired_val_earlier=pairing_val_earlier(pairing_val_earlier~=paired_val_earlier);
% % unpaired_val=[];
% % else
% % paired_val_earlier=[];
% % paired_val=[];
% % unpaired_val_earlier=[];
% % unpaired_val=[];
% % pairing_val_earlier_pending=cat(1,pairing_val_earlier_pending,pairing_val_earlier);
% % pairing_val_pending=cat(1,pairing_val_pending,pairing_val);
% % end
% % if ~isempty(paired_val_earlier)
% % freshness_here=freshness.continuation;
% % %kid_to_continue=unique(track_id_map_earlier(shape_map_earlier==paired_val_earlier));
% % %track_id_map(shape_map==paired_val)=kid_to_continue;
% % %track_status_map(shape_map==paired_val)=separation*100+merger*10+freshness_here;
% % %track_instvelx_allocnt{paired_val}=inter_step_disp(1)/(time(tcnt)-time(tcnt-1));
% % %track_instvely_allocnt{paired_val}=inter_step_disp(2)/(time(tcnt)-time(tcnt-1));
% % %if merger==1
% % %track_status_revised=get_digit(track_status_allocnt_earlier{paired_val_earlier},3,1)*100+merger*10+get_digit(track_status_allocnt_earlier{paired_val_earlier},3,3);
% % %track_status_map_earlier(track_id_map_earlier==kid_to_continue)=track_status_revised;
% % %track_status_allocnt_earlier{paired_val_earlier}=track_status_revised;
% % %end
% % end
% % for val=unpaired_val_earlier'
% % if track_tcntfrom_allocnt_earlier{val}==tcnt-1
% % freshness_here=freshness.geneterm;
% % else
% % freshness_here=freshness.termination;
% % end
% % %kid_to_close=unique(track_id_map_earlier(shape_map_earlier==val));
% % %track_status_revised=get_digit(track_status_allocnt_earlier{val},3,1)*100+merger*10+freshness_here;
% % %track_status_map_earlier(track_id_map_earlier==kid_to_close)=track_status_revised;
% % %track_status_allocnt_earlier{val}=track_status_revised;
% % end
% % for val=unpaired_val'
% % freshness_here=freshness.genesis;
% % kcnt=kcnt+1;
% % %track_id_map(shape_map==val)=str2double(sprintf('%04i%02i%02i%02i%02i',year_thismap{val},month_thismap{val},day_thismap{val},hour_thismap{val},shape_allocnt{val}));
% % %track_status_map(shape_map==val)=separation*100+merger*10+freshness_here;
% % end
% end
% if isempty(pairing_val_earlier_pending) && isempty(pairing_val_pending)
% break;
% end
% shape_map_earlier_reduced(~ismember(shape_map_earlier_reduced,pairing_val_earlier_pending))=0;
% dummy_map_allucnt=cell(1,numel(pairing_val_earlier_pending));
% for ucnt=1:numel(pairing_val_earlier_pending)
% dummy_map=zeros(nrow,ncol);
% dummy_map(shape_map_earlier_reduced==pairing_val_earlier_pending(ucnt))=1;
% ivt_min=min(ivt_earlier(dummy_map==1));
% ivt_max=max(ivt_earlier(dummy_map==1));
% ivt_cint=(ivt_max-ivt_min)/20;
% dummy_map(ivt_earlier<ivt_min+ivt_cint)=0;
% dummy_map=bwlabel(dummy_map);
% if is_geographic && is_global_lon
% dummy_map=rejoin_object(dummy_map);
% end
% ivt_masked=-ones(nrow,ncol);
% ivt_masked(dummy_map~=0)=ivt_earlier(dummy_map~=0);
% dummy_map(dummy_map~=dummy_map(find(ivt_masked==max(ivt_masked(:)),1,'first')))=0;
% dummy_map_allucnt{ucnt}=dummy_map;
% end
% dummy_map=nansum(cat(3,dummy_map_allucnt{:}),3);
% shape_map_earlier_reduced(dummy_map==0)=0;
% shape_map_reduced(~ismember(shape_map_reduced,pairing_val_pending))=0;
% dummy_map_allucnt=cell(1,numel(pairing_val_pending));
% for ucnt=1:numel(pairing_val_pending)
% dummy_map=zeros(nrow,ncol);
% dummy_map(shape_map_reduced==pairing_val_pending(ucnt))=1;
% ivt_min=min(ivt(dummy_map==1));
% ivt_max=max(ivt(dummy_map==1));
% ivt_cint=(ivt_max-ivt_min)/20;
% dummy_map(ivt<ivt_min+ivt_cint)=0;
% dummy_map=bwlabel(dummy_map);
% if is_geographic && is_global_lon
% dummy_map=rejoin_object(dummy_map);
% end
% ivt_masked=-ones(nrow,ncol);
% ivt_masked(dummy_map~=0)=ivt(dummy_map~=0);
% dummy_map(dummy_map~=dummy_map(find(ivt_masked==max(ivt_masked(:)),1,'first')))=0;
% dummy_map_allucnt{ucnt}=dummy_map;
% end
% dummy_map=nansum(cat(3,dummy_map_allucnt{:}),3);
% shape_map_reduced(dummy_map==0)=0;
% end
end

%track_id_allocnt=cell(1,numel(unique_val));
%track_status_allocnt=cell(1,numel(unique_val));
for ocnt=1:numel(unique_val)
%track_id_allocnt{ocnt}=unique(track_id_map(shape_map==ocnt));
%track_status_allocnt{ocnt}=unique(track_status_map(shape_map==ocnt));
end

% if tcnt>=2 & ~isempty(track_ntime_max)
% length_history=ncread(outfile,'length',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% width_history=ncread(outfile,'width',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% ivtx_history=ncread(outfile,'ivtx',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% ivty_history=ncread(outfile,'ivty',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_id_history=ncread(outfile,'kid',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_time_history=permute(repmat(ncread(outfile,'time',tcnt-track_ntime_max,track_ntime_max),[1,ncol,1,1]),[2,3,1,4]);
% %track_lifetime_history=ncread(outfile,'klifetime',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_distance_history=ncread(outfile,'kdist',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_speed_history=ncread(outfile,'kspeed',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_normage_history=ncread(outfile,'knormage',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_ivtx_history=ncread(outfile,'kivtx',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_ivty_history=ncread(outfile,'kivty',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_ivtdir_history=ncread(outfile,'kivtdir',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_displacementx_history=ncread(outfile,'kdispx',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_displacementy_history=ncread(outfile,'kdispy',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_displacementdir_history=ncread(outfile,'kdispdir',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_instvelx_history=ncread(outfile,'kinstvelx',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_instvely_history=ncread(outfile,'kinstvely',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% track_instveldir_history=ncread(outfile,'kinstveldir',[1,zcnt,tcnt-track_ntime_max,ecnt],[inf,1,track_ntime_max,1]);
% % for track_id=unique(track_id_map_earlier(track_status_map_earlier~=0 & (mod(track_status_map_earlier,10)==3 | mod(track_status_map_earlier,10)==0)))'
% % exact_step_time=track_time_history(track_id_history==track_id);
% % inter_step_duration=diff(exact_step_time);
% % inter_step_instvelx=track_instvelx_history(track_id_history==track_id); inter_step_instvelx=inter_step_instvelx(2:end);
% % inter_step_instvely=track_instvely_history(track_id_history==track_id); inter_step_instvely=inter_step_instvely(2:end);
% % track_lifetime_history(track_id_history==track_id)=nansum(inter_step_duration);
% % track_distance_history(track_id_history==track_id)=nansum(sqrt(inter_step_instvelx.^2+inter_step_instvely.^2).*inter_step_duration);
% % track_speed_history(track_id_history==track_id)=track_distance_history(track_id_history==track_id)./track_lifetime_history(track_id_history==track_id);
% % track_normage_history(track_id_history==track_id)=(track_time_history(track_id_history==track_id)-track_time_history(find(track_id_history==track_id,1,'first')))./track_lifetime_history(track_id_history==track_id);
% % track_ivtx_history(track_id_history==track_id)=nansum(ivtx_history(track_id_history==track_id).*length_history(track_id_history==track_id).*width_history(track_id_history==track_id))/nansum(length_history(track_id_history==track_id).*width_history(track_id_history==track_id));
% % track_ivty_history(track_id_history==track_id)=nansum(ivty_history(track_id_history==track_id).*length_history(track_id_history==track_id).*width_history(track_id_history==track_id))/nansum(length_history(track_id_history==track_id).*width_history(track_id_history==track_id));
% % track_ivtdir_history(track_id_history==track_id)=atan_in_azimuth(track_ivty_history(track_id_history==track_id),track_ivtx_history(track_id_history==track_id));
% % track_displacementx_history(track_id_history==track_id)=nansum(inter_step_instvelx.*inter_step_duration);
% % track_displacementy_history(track_id_history==track_id)=nansum(inter_step_instvely.*inter_step_duration);
% % track_displacementdir_history(track_id_history==track_id)=atan_in_azimuth(track_displacementy_history(track_id_history==track_id),track_displacementx_history(track_id_history==track_id));
% % switch numel(inter_step_duration)
% % case 0
% % exact_step_instvelx=NaN;
% % exact_step_instvely=NaN;
% % case 1
% % exact_step_instvelx=repmat(inter_step_instvelx,[1,2]);
% % exact_step_instvely=repmat(inter_step_instvely,[1,2]);
% % otherwise
% % exact_step_instvelx=interp1(exact_step_time(1:end-1)+0.5*inter_step_duration,inter_step_instvelx,exact_step_time);
% % exact_step_instvelx([1,end])=inter_step_instvelx([1,end]);
% % exact_step_instvely=interp1(exact_step_time(1:end-1)+0.5*inter_step_duration,inter_step_instvely,exact_step_time);
% % exact_step_instvely([1,end])=inter_step_instvely([1,end]);
% % end
% % track_instvelx_history(track_id_history==track_id)=exact_step_instvelx;
% % track_instvely_history(track_id_history==track_id)=exact_step_instvely;
% % track_instveldir_history(track_id_history==track_id)=atan_in_azimuth(track_instvely_history(track_id_history==track_id),track_instvelx_history(track_id_history==track_id));
% % end
% end

shape_map(shape_map==0)=-9999;
%axis_map(axis_map==0)=-9999;
%tnsct_map(tnsct_map==0)=-9999;
%lfloc_map(lfloc_map==0)=-9999;
%track_id_map(track_id_map==0)=-9999;
%track_status_map(track_status_map==0)=-9999;
if tcnt>=2
%track_status_map_earlier(track_status_map_earlier==0)=-9999;
end

map{1}={'shapemap','Shape','none',shape_map,'int16'};
%map{2}={'axismap','Axis','none',axis_map,'double'};
%map{3}={'tnsctmap','Transect','none',tnsct_map,'double'};
%map{4}={'lflocmap','Landfall Location','none',lfloc_map,'int16'};
%map{5}={'kidmap','Track: ID','none',track_id_map,'double'};
%map{6}={'kstatusmap','Track: Status','none',track_status_map,'int16'};
%attr{1}={'year','Year','none',cat(2,year_thismap{:})};
%attr{2}={'month','Month','none',cat(2,month_thismap{:})};
%attr{3}={'day','Day','none',cat(2,day_thismap{:})};
%attr{4}={'hour','Hour','none',cat(2,hour_thismap{:})};
%attr{5}={'length','Length','m',cat(2,object_length_allocnt{:})};
%attr{6}={'width','Effective Width','m',cat(2,object_width_allocnt{:})};
%attr{7}={'clon','Centroid Longitude','degree',cat(2,centroid_lon_allocnt{:})};
%attr{8}={'clat','Centroid Latitude','degree',cat(2,centroid_lat_allocnt{:})};
%attr{9}={'tlon','Tail Longitude','degree',cat(2,axistail_lon_allocnt{:})};
%attr{10}={'tlat','Tail Latitude','degree',cat(2,axistail_lat_allocnt{:})};
%attr{11}={'hlon','Head Longitude','degree',cat(2,axishead_lon_allocnt{:})};
%attr{12}={'hlat','Head Latitude','degree',cat(2,axishead_lat_allocnt{:})};
%attr{13}={'ivtx','Mean Zonal IVT','kg m^-1 s^-1',cat(2,object_ivtx_allocnt{:})};
%attr{14}={'ivty','Mean Meridional IVT','kg m^-1 s^-1',cat(2,object_ivty_allocnt{:})};
%attr{15}={'ivtdir','Direction of Mean IVT','degree from north going clockwise',cat(2,object_ivtdir_allocnt{:})};
%attr{16}={'ivtdircoh','IVT Direction Coherence','none',cat(2,object_ivtdirspread_allocnt{:})};
%attr{17}={'width2','Transect Width','m',cat(2,object_width2_allocnt{:})};
%attr{18}={'tivt','Total IVT Across Transect','kg s^-1',cat(2,tnsct_tivt_allocnt{:})};
%attr{19}={'lflon','Landfall Longitude','degree',cat(2,lfloc_lon_allocnt{:})};
%attr{20}={'lflat','Landfall Latitude','degree',cat(2,lfloc_lat_allocnt{:})};
%attr{21}={'lfivtx','Zonal IVT at Landfall Location','kg m^-1 s^-1',cat(2,lfloc_ivtx_allocnt{:})};
%attr{22}={'lfivty','Meridional IVT at Landfall Location','kg m^-1 s^-1',cat(2,lfloc_ivty_allocnt{:})};
%attr{23}={'lfivtdir','IVT Direction at Landfall Location','degree from north going clockwise',cat(2,lfloc_ivtdir_allocnt{:})};
%attr{24}={'kid','Track: ID','none',cat(2,track_id_allocnt{:})};
%attr{25}={'kstatus','Track: Status','none',cat(2,track_status_allocnt{:})};
%attr{26}={'klifetime','Track: Lifetime','s',NaN(size(unique_val))'};
%attr{27}={'kdist','Track: Travel Distance (Summation of All Segments)','m',NaN(size(unique_val))'};
%attr{28}={'kspeed','Track: Travel Speed (Division of Travel Distance by Lifetime)','m s^-1',NaN(size(unique_val))'};
%attr{29}={'knormage','Track: Normalized Age','none',NaN(size(unique_val))'};
%attr{30}={'kivtx','Track: Mean Zonal IVT','kg m^-1 s^-1',NaN(size(unique_val))'};
%attr{31}={'kivty','Track: Mean Meridional IVT','kg m^-1 s^-1',NaN(size(unique_val))'};
%attr{32}={'kivtdir','Track: Direction of Mean IVT','degree from north going clockwise',NaN(size(unique_val))'};
%attr{33}={'kdispx','Track: Net Zonal Displacement','m',NaN(size(unique_val))'};
%attr{34}={'kdispy','Track: Net Meridional Displacement','m',NaN(size(unique_val))'};
%attr{35}={'kdispdir','Track: Direction of Net Displacement','degree from north going clockwise',NaN(size(unique_val))'};
%attr{36}={'kinstvelx','Track: Instantaneous Zonal Travel Velocity','m s^-1',cat(2,track_instvelx_allocnt{:})};
%attr{37}={'kinstvely','Track: Instantaneous Meridional Travel Velocity','m s^-1',cat(2,track_instvely_allocnt{:})};
%attr{38}={'kinstveldir','Track: Direction of Instantaneous Travel Velocity','degree from north going clockwise',NaN(size(unique_val))'};
%attv{1}={'axisidx','Pixel Indices of Axis','none',catx(2,axis_idx_allocnt{:})};
%attv{2}={'axislon','Longitudes of Smoothed Axis','degree',catx(2,axis_lon_allocnt{:})};
%attv{3}={'axislat','Latitudes of Smoothed Axis','degree',catx(2,axis_lat_allocnt{:})};

if all([zcnt,tcnt,ecnt]==1)
if exist(outfile,'file')
delete(outfile);
end
%nccreate(outfile,'islnd','dimensions',{'lon',nrow,'lat',ncol},'chunksize',[nrow,ncol],'datatype','int16','fillvalue',-9999,'format','netcdf4','deflatelevel',9);
%nccreate(outfile,'iscst','dimensions',{'lon',nrow,'lat',ncol},'chunksize',[nrow,ncol],'datatype','int16','fillvalue',-9999,'format','netcdf4','deflatelevel',9);
if is_geographic
nccreate(outfile,'lon','dimensions',{'lon',nrow});
nccreate(outfile,'lat','dimensions',{'lat',ncol});
else
nccreate(outfile,'lon','dimensions',{'lon',nrow,'lat',ncol});
nccreate(outfile,'lat','dimensions',{'lon',nrow,'lat',ncol});
end
nccreate(outfile,'lev','dimensions',{'lev',nlev});
nccreate(outfile,'time','dimensions',{'time',inf});
nccreate(outfile,'ens','dimensions',{'ens',nens});
for mcnt=1:numel(map)
nccreate(outfile,map{mcnt}{1},'dimensions',{'lon',nrow,'lat',ncol,'lev',nlev,'time',inf,'ens',nens},'chunksize',[nrow,ncol,1,1,1],'datatype',map{mcnt}{5},'fillvalue',-9999,'format','netcdf4','deflatelevel',9);
end
%for acnt=1:numel(attr)
%nccreate(outfile,attr{acnt}{1},'dimensions',{'lat',ncol,'lev',nlev,'time',inf,'ens',nens},'chunksize',[ncol,1,min(nrow,ntime),1],'datatype','double','fillvalue',NaN,'format','netcdf4','deflatelevel',9);
%end
%for acnt=1:numel(attv)
%nccreate(outfile,attv{acnt}{1},'dimensions',{'lon',nrow,'lat',ncol,'lev',nlev,'time',inf,'ens',nens},'chunksize',[nrow,ncol,1,1,1],'datatype','double','fillvalue',NaN,'format','netcdf4','deflatelevel',9);
%end
%nccreate(outfile,'numobj','dimensions',{'lon',nrow,'lat',ncol,'lev',nlev,'time',inf,'ens',nens},'chunksize',[nrow,ncol,1,1,1],'datatype','int16','fillvalue',-9999,'format','netcdf4','deflatelevel',9);
%nccreate(outfile,'kcnt','dimensions',{'lev',nlev,'time',inf,'ens',nens},'chunksize',[1,1,1],'datatype','int32','fillvalue',-9999,'format','netcdf4','deflatelevel',9);
%ncwrite(outfile,'islnd',islnd);
%ncwrite(outfile,'iscst',iscst);
if is_geographic
ncwrite(outfile,'lon',lon(:,1));
ncwrite(outfile,'lat',lat(1,:));
else
ncwrite(outfile,'lon',lon);
ncwrite(outfile,'lat',lat);
end
ncwrite(outfile,'lev',lev);
ncwrite(outfile,'time',time);
ncwrite(outfile,'ens',ens);
%ncwriteatt(outfile,'islnd','long_name','Is Land (Major Landmasses Only)');
%ncwriteatt(outfile,'iscst','long_name','Is Coast (Major Landmasses Only; Inland Water Bodies Not Considered)');
ncwriteatt(outfile,'lon','units','degrees_east');
ncwriteatt(outfile,'lat','units','degrees_north');
ncwriteatt(outfile,'lev','units','m');
ncwriteatt(outfile,'time','units',sprintf('seconds since %s',datestr(year_month_day_hour_minute_second(1,:),'yyyy-mm-dd HH:MM:SS')));
ncwriteatt(outfile,'ens','axis','e');
if(~isempty(cal))
ncwriteatt(outfile,'time','calendar',cal);
end
for mcnt=1:numel(map)
ncwriteatt(outfile,map{mcnt}{1},'long_name',map{mcnt}{2});
ncwriteatt(outfile,map{mcnt}{1},'units',map{mcnt}{3});
end
%for acnt=1:numel(attr)
%ncwriteatt(outfile,attr{acnt}{1},'long_name',attr{acnt}{2});
%ncwriteatt(outfile,attr{acnt}{1},'units',attr{acnt}{3});
%end
%for acnt=1:numel(attv)
%ncwriteatt(outfile,attv{acnt}{1},'long_name',attv{acnt}{2});
%ncwriteatt(outfile,attv{acnt}{1},'units',attv{acnt}{3});
%end
%ncwriteatt(outfile,'numobj','long_name','Number of Objects Retained at Each Detection Stage for Each IVT Limit (Ancillary Data for Interested Users)');
%ncwriteatt(outfile,'kcnt','long_name','Track Counter (Maximum ID of All Registered Tracks)');
ncwriteatt(outfile,'/','title','Global Atmospheric River Database');
ncwriteatt(outfile,'/','version',datestr(now,'yyyy.mm.dd'));
ncwriteatt(outfile,'/','creation_date',datestr(now));
ncwriteatt(outfile,'/','tARget_version',tARget_version);
ncwriteatt(outfile,'/','references','(1) Guan, B., and D. E. Waliser (2015), Detection of atmospheric rivers: Evaluation and application of an algorithm for global studies, J. Geophys. Res. Atmos., 120, 12514-12535, doi:10.1002/2015JD024257. (2) Guan, B., D. E. Waliser, and F. M. Ralph (2018), An inter-comparison between reanalysis and dropsonde observations of the total water vapor transport in individual atmospheric rivers, J. Hydrometeorol., 19, 321-337, doi:10.1175/JHM-D-17-0114.1. (3) Guan, B., and D. E. Waliser (2019), Tracking atmospheric rivers globally: Spatial distributions and temporal evolution of life cycle characteristics, J. Geophys. Res. Atmos., 124, 12523–12552, doi:10.1029/2019JD031205. (4) Guan, B., and D. E. Waliser (2024), A regionally refined quarter-degree global atmospheric rivers database based on ERA5, Sci. Data, accepted.');
end

if isequal([zcnt,tcnt,ecnt],[1,1,1]) || isequal([zcnt,tcnt,ecnt],[1,tcnt_restart,1])
outncid=netcdf.open(outfile,'write');
end

for mcnt=1:numel(map)
ncwrite(outfile,map{mcnt}{1},map{mcnt}{4},[1,1,zcnt,tcnt,ecnt]);
end
%if numel(unique_val)~=0
%for acnt=1:numel(attr)
%ncwrite(outfile,attr{acnt}{1},attr{acnt}{4}',[1,zcnt,tcnt,ecnt]);
%end
%for acnt=1:numel(attv)
%ncwrite(outfile,attv{acnt}{1},attv{acnt}{4},[1,1,zcnt,tcnt,ecnt]);
%end
%end

%if tcnt>=2
%ncwrite(outfile,'kstatusmap',track_status_map_earlier,[1,1,zcnt,tcnt-1,ecnt]);
%ncwrite(outfile,'kstatus',cat(2,track_status_allocnt_earlier{:})',[1,zcnt,tcnt-1,ecnt]);
%end

% if tcnt>=2 & ~isempty(track_ntime_max)
% %ncwrite(outfile,'klifetime',track_lifetime_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kdist',track_distance_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kspeed',track_speed_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'knormage',track_normage_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kivtx',track_ivtx_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kivty',track_ivty_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kivtdir',track_ivtdir_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kdispx',track_displacementx_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kdispy',track_displacementy_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kdispdir',track_displacementdir_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kinstvelx',track_instvelx_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kinstvely',track_instvely_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% ncwrite(outfile,'kinstveldir',track_instveldir_history,[1,zcnt,tcnt-track_ntime_max,ecnt]);
% end

%ncwrite(outfile,'numobj',num_object,[1,1,zcnt,tcnt,ecnt]);
%ncwrite(outfile,'kcnt',kcnt,[zcnt,tcnt,ecnt]);
ncwriteatt(outfile,'time','ntime_written',tcnt);

exitfile=fullfile(outdir,'tcnt_exit.txt');
if (exist(exitfile,'file') && load(exitfile)==tcnt) && zcnt==nlev && ecnt==nens
exit;
end

end

end

fprintf(1,' done in %.3f second(s); elapsed %.1f hour(s); ETA %.1f hour(s).\n',toc(tic_thisstep),toc/3600,toc(tic_mainloop)/(tcnt-tcnt_restart+1)*(ntime-tcnt)/3600);

tcnt=tcnt+1;
end

end

netcdf.close(outncid);
if exist(exitfile,'file')
system(['rm ',exitfile]);
end
disp(' ');
fprintf(1,'Program successfully ended at %s.\n',datestr(now)); tic;
end

function degree=atan_in_azimuth(y,x)
degree=mod(90-rad2deg(atan2(y,x)),360);
degree(x==0 & y==0)=NaN;
end

%function digit=get_digit(number,length,position)
%string=num2str(number,['%0',num2str(length),'i']);
%digit=str2double(string(position));
%end

function [start_idx,end_idx]=consectrue(mask)
if iscolumn(mask)
mask=[false;mask;false];
else
mask=[false,mask,false];
end
maskdiff=diff(mask);
start_idx=find(maskdiff==1);
end_idx=find(maskdiff==-1)-1;
end

function out=prctilew(data,weight,prctile)
volumn=size(data);
data=reshape(data,volumn(1),[]);
weight=reshape(weight,volumn(1),[]);
out=nan(1,size(data,2));
for cnt=1:size(data,2)
data_slice=data(:,cnt);
weight_slice=weight(:,cnt);
[data_sorted,idx_sorted]=sort(data_slice);
weight_sorted=weight_slice(idx_sorted);
weight_sorted_cumsum=cumsum(weight_sorted);
prctile_at_data_sorted=(weight_sorted_cumsum-0.5*weight_sorted)/nansum(weight_sorted)*100;
prctile_at_data_sorted=[0;prctile_at_data_sorted;100];
data_sorted=[data_sorted(1);data_sorted;data_sorted(end)];
[prctile_at_data_sorted,idx_unique]=unique(prctile_at_data_sorted,'stable');
data_sorted=data_sorted(idx_unique);
out(cnt)=interp1(prctile_at_data_sorted,data_sorted,prctile);
end
out=reshape(out,[1,volumn(2:end)]);
end

% function array_out=shift_array(array_in,k,circular)
% cnt=1;
% array_in=circshift(array_in,k(cnt),cnt);
% if ~circular(cnt)
% if k(cnt)<0
% array_in(end+k(cnt)+1:end,:)=0;
% else
% array_in(1:k(cnt),:)=0;
% end
% end
% cnt=2;
% array_in=circshift(array_in,k(cnt),cnt);
% if ~circular(cnt)
% if k(cnt)<0
% array_in(:,end+k(cnt)+1:end)=0;
% else
% array_in(:,1:k(cnt))=0;
% end
% end
% array_out=array_in;
% end

% function data_out=catx(varargin)
% dim=varargin{1};
% data_in=varargin(2:end);
% vec_is_col=any(cellfun(@iscolumn,data_in));
% max_numel=max(cellfun(@numel,data_in));
% if dim==1
% if vec_is_col
% data_out=NaN(numel(data_in)*max_numel,1);
% for cnt=1:numel(data_in)
% data_out(((cnt-1)*max_numel+1):((cnt-1)*max_numel+numel(data_in{cnt})))=data_in{cnt};
% end
% else
% data_out=NaN(numel(data_in),max_numel);
% for cnt=1:numel(data_in)
% data_out(cnt,1:numel(data_in{cnt}))=data_in{cnt};
% end
% end
% else
% if ~vec_is_col
% data_out=NaN(1,numel(data_in)*max_numel);
% for cnt=1:numel(data_in)
% data_out(((cnt-1)*max_numel+1):((cnt-1)*max_numel+numel(data_in{cnt})))=data_in{cnt};
% end
% else
% data_out=NaN(max_numel,numel(data_in));
% for cnt=1:numel(data_in)
% data_out(1:numel(data_in{cnt}),cnt)=data_in{cnt};
% end
% end
% end
% end

function myidx=lonlat2idx(mylon,mylat,lon,lat,pixelarea,is_geographic,is_even_lat,earth_radius)
[n,m]=size(mylon);
[nrow,ncol]=size(lon);
lons=lon(1,1); dlon=lon(2,1)-lon(1,1);
lats=lat(1,1); dlat=lat(1,2)-lat(1,1); latdef=lat(1,:);
mylon=mylon(:);
mylat=mylat(:);
lon=lon(:);
lat=lat(:);
mylon(mylon<min(lon))=mylon(mylon<min(lon))+360; mylon(mylon>=min(lon)+360)=mylon(mylon>=min(lon)+360)-360;
if is_geographic && is_even_lat
myrow=round((mylon-lons)/dlon+1); myrow(myrow>360/dlon)=myrow(myrow>360/dlon)-360/dlon;
mycol=round((mylat-lats)/dlat+1);
myrow(myrow<1)=nan; myrow(myrow>nrow)=nan;
mycol(mycol<1)=nan; mycol(mycol>ncol)=nan;
myidx=sub2ind([nrow,ncol],myrow,mycol);
elseif is_geographic && ~is_even_lat
myrow=round((mylon-lons)/dlon+1); myrow(myrow>360/dlon)=myrow(myrow>360/dlon)-360/dlon;
edges=[latdef(1)-(latdef(2)-latdef(1))/2,(latdef(1:end-1)+latdef(2:end))/2,latdef(end)+(latdef(end)-latdef(end-1))/2];
[~,~,mycol]=histcounts(mylat,edges);
myrow(myrow<1)=nan; myrow(myrow>nrow)=nan;
mycol(mycol<1)=nan; mycol(mycol>ncol)=nan;
myidx=Sub2Ind([nrow,ncol],myrow,mycol);
%disp(myidx);
else
mydist=nan(size(mylon));
myidx=nan(size(mylon));
for query_point_cnt=1:numel(mylon)
dist=distance(mylat(query_point_cnt),mylon(query_point_cnt),lat,lon,earth_radius);
[min_dist,min_loc]=min(dist);
mydist(query_point_cnt)=min_dist;
myidx(query_point_cnt)=min_loc;
end
myidx(mydist>sqrt(max(pixelarea(:))))=nan;
end
myidx=reshape(myidx,[n,m]);
end

function map_out=rejoin_object(map_in)
mapedge_rawlabel=map_in([1,end],:,:);
mapedge_newlabel=bwlabeln(mapedge_rawlabel);
for ocnt=unique(mapedge_newlabel(mapedge_newlabel~=0))'
map_in(ismember(map_in,mapedge_rawlabel(mapedge_newlabel==ocnt)))=min(mapedge_rawlabel(mapedge_newlabel==ocnt));
mapedge_rawlabel=map_in([1,end],:);
end
unique_val=unique(map_in(map_in~=0));
for ocnt=1:numel(unique_val)
map_in(map_in==unique_val(ocnt))=ocnt;
end
map_out=map_in;
end

% function [disp,ocnt]=displace_object(lon,lat,pixelarea,ivt1,mask1,search_radius,ivt2,mask2,is_geographic,is_global_lon,is_even_lat,earth_radius)
% [n,m]=size(lon);
% clon1=mod(rad2deg(angle(nansum(exp(1i*deg2rad(lon(mask1))).*pixelarea(mask1).*ivt1(mask1))/nansum(pixelarea(mask1).*ivt1(mask1)))),360);
% clat1=nansum(lat(mask1).*pixelarea(mask1).*ivt1(mask1))/nansum(pixelarea(mask1).*ivt1(mask1));
% ivt1=ivt1.*mask1;
% centroid1=zeros(n,m); centroid1(lonlat2idx(clon1,clat1,lon,lat,pixelarea,is_geographic,is_even_lat,earth_radius))=1;
% [crow1,ccol1]=find(centroid1==1);
% distance_centroid1_to_globe=distance(lat(centroid1==1),lon(centroid1==1),lat,lon,earth_radius);
% stride=max(floor((pi*search_radius^2/max(pixelarea(:)))^0.25),1);
% distance_centroid1_to_globe_strided=NaN(n,m);
% distance_centroid1_to_globe_strided(1:stride:n,1:stride:m)=distance_centroid1_to_globe(1:stride:n,1:stride:m);
% unique_val=unique(mask2(mask2~=0));
% rc=NaN(3,numel(unique_val));
% for ucnt=1:numel(unique_val)
% ivt2_thisobject=zeros(n,m);
% ivt2_thisobject(mask2==unique_val(ucnt))=ivt2(mask2==unique_val(ucnt));
% [search_row,search_col]=find(distance_centroid1_to_globe_strided<=max(search_radius,min(distance_centroid1_to_globe_strided(:))));
% similarity_index=zeros(numel(search_row),1);
% for scnt=1:numel(search_row)
% row_offset=search_row(scnt)-crow1;
% col_offset=search_col(scnt)-ccol1;
% ivt1_shifted=shift_array(ivt1,[row_offset,col_offset],[is_geographic && is_global_lon,0]);
% similarity_index(scnt)= ...
% nansum(min(pixelarea(:).*ivt1_shifted(:),pixelarea(:).*ivt2_thisobject(:)))/ ...
% nansum(max(pixelarea(:).*ivt1_shifted(:),pixelarea(:).*ivt2_thisobject(:)));
% end
% [~,max_loc]=max(similarity_index);
% row_offset=search_row(max_loc)-crow1;
% col_offset=search_col(max_loc)-ccol1;
% ivt1a=shift_array(ivt1,[row_offset,col_offset],[is_geographic && is_global_lon,0]);
% centroid1a=shift_array(centroid1,[row_offset,col_offset],[is_geographic && is_global_lon,0]);
% [crow1a,ccol1a]=find(centroid1a==1);
% distance_centroid1a_to_globe=distance(lat(centroid1a==1),lon(centroid1a==1),lat,lon,earth_radius);
% [search_row,search_col]=find(distance_centroid1a_to_globe<=sqrt(2)*stride*sqrt(max(pixelarea(:))) & distance_centroid1_to_globe<=search_radius);
% similarity_index=zeros(numel(search_row),1);
% for scnt=1:numel(search_row)
% row_offset=search_row(scnt)-crow1a;
% col_offset=search_col(scnt)-ccol1a;
% ivt1_shifted=shift_array(ivt1a,[row_offset,col_offset],[is_geographic && is_global_lon,0]);
% similarity_index(scnt)= ...
% nansum(min(pixelarea(:).*ivt1_shifted(:),pixelarea(:).*ivt2_thisobject(:)))/ ...
% nansum(max(pixelarea(:).*ivt1_shifted(:),pixelarea(:).*ivt2_thisobject(:)));
% end
% [max_val,max_loc]=max(similarity_index);
% row_offset=search_row(max_loc)-crow1a;
% col_offset=search_col(max_loc)-ccol1a;
% centroid1b=shift_array(centroid1a,[row_offset,col_offset],[is_geographic && is_global_lon,0]);
% rc(:,ucnt)=[max_val,lon(centroid1b==1),lat(centroid1b==1)]';
% end
% [~,max_loc]=max(rc(1,:));
% [dist,azi]=distance(lat(centroid1==1),lon(centroid1==1),rc(3,max_loc),rc(2,max_loc),earth_radius);
% dispx=dist.*sin(deg2rad(azi));
% dispy=dist.*cos(deg2rad(azi));
% disp=[dispx,dispy];
% ocnt=unique_val(max_loc);
% end

function [axis_idx,iswhirl]=object_axis(lon,lat,pixelarea,ivt,ivtx,ivty,mask,is_geographic,is_global_lon,earth_radius)
cressman_area_limit=0.25;
cressman_radius_limit=500e3;
[nrow,ncol]=size(lon);
ivt_masked=NaN(nrow,ncol);
ivt_masked(mask)=ivt(mask);
[~,axis_idx]=max(ivt_masked(:));
axis_quality=1;
iswhirl=0;
for fly_direction={'downstream','upstream'}
while true
[current_row,current_col]=ind2sub([nrow,ncol],axis_idx(end));
distance_to_shape=distance(lat(current_row,current_col),lon(current_row,current_col),lat(mask),lon(mask),earth_radius);
pixelarea_of_shape=pixelarea(mask);
[distance_to_shape_sorted,sorted_idx]=sort(distance_to_shape);
cressman_radius=min(distance_to_shape_sorted(find(cumsum(pixelarea_of_shape(sorted_idx),'omitnan')/nansum(pixelarea_of_shape)<=cressman_area_limit,1,'last')),cressman_radius_limit);
if isempty(cressman_radius)
cressman_radius=0.001;
end
weight_cressman=(cressman_radius^2-distance_to_shape.^2)./(cressman_radius^2+distance_to_shape.^2);
weight_cressman(weight_cressman<=0)=NaN;
current_ivtx_cressman=nansum(ivtx(mask).*pixelarea(mask).*weight_cressman)/nansum(pixelarea(mask).*weight_cressman);
current_ivty_cressman=nansum(ivty(mask).*pixelarea(mask).*weight_cressman)/nansum(pixelarea(mask).*weight_cressman);
current_ivtdir_cressman=atan_in_azimuth(current_ivty_cressman,current_ivtx_cressman);
neighbor_row_all=[];
neighbor_col_all=[];
for row_offset=-1:1
for col_offset=-1:1
neighbor_row=current_row+row_offset;
neighbor_col=current_col+col_offset;
if is_geographic && is_global_lon
if neighbor_row<1
neighbor_row=neighbor_row+nrow;
end
if neighbor_row>nrow
neighbor_row=neighbor_row-nrow;
end
end
if (neighbor_row>=1 && neighbor_row<=nrow && neighbor_col>=1 && neighbor_col<=ncol) && ~(row_offset==0 && col_offset==0)
neighbor_row_all=cat(1,neighbor_row_all,neighbor_row);
neighbor_col_all=cat(1,neighbor_col_all,neighbor_col);
end
end
end
azimuth_to_neighbor_all=azimuth(lat(current_row,current_col),lon(current_row,current_col),lat(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all)),lon(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all)),earth_radius);
if strcmp(fly_direction,'downstream')
degree_diff=mod(current_ivtdir_cressman-azimuth_to_neighbor_all,360); degree_diff(degree_diff>180)=360-degree_diff(degree_diff>180); degree_diff=round(degree_diff/45)*45;
else
degree_diff=mod(current_ivtdir_cressman+180-azimuth_to_neighbor_all,360); degree_diff(degree_diff>180)=360-degree_diff(degree_diff>180); degree_diff=round(degree_diff/45)*45;
end
if numel(axis_idx)>=2
azimuth_from_previous=azimuth(lat(axis_idx(end-1)),lon(axis_idx(end-1)),lat(current_row,current_col),lon(current_row,current_col),earth_radius);
degree_diff2=mod(azimuth_from_previous-azimuth_to_neighbor_all,360); degree_diff2(degree_diff2>180)=360-degree_diff2(degree_diff2>180); degree_diff2=round(degree_diff2/45)*45;
end
if numel(axis_idx)>=2
neighbor_row_select=neighbor_row_all(degree_diff<=45 & degree_diff2<=90);
neighbor_col_select=neighbor_col_all(degree_diff<=45 & degree_diff2<=90);
else
neighbor_row_select=neighbor_row_all(degree_diff<=45);
neighbor_col_select=neighbor_col_all(degree_diff<=45);
end
[~,max_loc]=max(ivt(sub2ind([nrow,ncol],neighbor_row_select,neighbor_col_select)));
next_idx=sub2ind([nrow,ncol],neighbor_row_select(max_loc),neighbor_col_select(max_loc));
next_quality=1;
if ~isempty(next_idx) && mask(next_idx)==0
if numel(axis_idx)>=2
neighbor_row_select=neighbor_row_all(mask(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all))==1 & degree_diff<=90 & ~ismember(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all),axis_idx) & degree_diff2<=90);
neighbor_col_select=neighbor_col_all(mask(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all))==1 & degree_diff<=90 & ~ismember(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all),axis_idx) & degree_diff2<=90);
else
neighbor_row_select=neighbor_row_all(mask(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all))==1 & degree_diff<=90 & ~ismember(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all),axis_idx));
neighbor_col_select=neighbor_col_all(mask(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all))==1 & degree_diff<=90 & ~ismember(sub2ind([nrow,ncol],neighbor_row_all,neighbor_col_all),axis_idx));
end
[~,max_loc]=max(ivt(sub2ind([nrow,ncol],neighbor_row_select,neighbor_col_select)));
next_idx=sub2ind([nrow,ncol],neighbor_row_select(max_loc),neighbor_col_select(max_loc));
next_quality=0;
end
if isempty(next_idx) || mask(next_idx)==0 || ismember(next_idx,axis_idx)
if ~isempty(next_idx) && ismember(next_idx,axis_idx) && numel(axis_idx)-find(axis_idx==next_idx)+1>=4
iswhirl=1;
axis_idx=axis_idx(find(axis_idx==next_idx):end);
end
break;
else
axis_idx=cat(1,axis_idx,next_idx);
axis_quality=cat(1,axis_quality,next_quality);
end
end
[start_idx,end_idx]=consectrue(~axis_quality);
if ~isempty(end_idx) && end_idx(end)==numel(axis_idx) && ~iswhirl
axis_idx(start_idx(end):end_idx(end))=[];
axis_quality(start_idx(end):end_idx(end))=[];
end
if strcmp(fly_direction,'downstream') && iswhirl
break;
end
axis_idx=flip(axis_idx);
axis_quality=flip(axis_quality);
end
end

function out=Sub2Ind(sz,varargin)
  out=varargin{1};
  for i=2:numel(varargin)
      out=out+(varargin{i}-1)*(sz(i-1));
  end
end
