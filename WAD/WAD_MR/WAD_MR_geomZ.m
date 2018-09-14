% ------------------------------------------------------------------------
% WAD_MR is an MRI analysis module written for IQC.
% NVKF WAD IQC software is a framework for automatic analysis of DICOM objects.
% 
% Copyright 2012-2013  Joost Kuijer / jpa.kuijer@vumc.nl
% 
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% ------------------------------------------------------------------------

function WAD_MR_geomZ( i_iSeries, sSeries, sParams )
% Evaluate length of phantom in head-feet direction on mid-saggital slice (the actual length is 148 mm)
%
% Input: SAG series on ACR phantom, for best results tilt 2 - 5 degrees (edge pixel subsampling)
%        Analysis is performed on first image in series
%        Parameters: none
%
% Output: written via WAD_resultsAppend*() interface
% 
% This module consists of the following seven steps:
% 1. Calculation of the row APPROXIMATELY centered in the middle of the phantom ("center row")
%    1. the image intensities along each row are summed
%    2. the gradient of summed intensities is calculated
%    3. the "upper row" is the max after multiplying the gradient with a function to find a positive step
%    4. the "lower row" is the min after multiplying the gradient with a function to fing a negative step
%    The "center row" will be used for
%    - help finding the "center column"
%    - for finding the precise edges a given distance interval above and below the "center row"
%      (to minimize the chance of detecting wrong edges)
%
% 2. Calculation of the column APPROXIMATELY centered in the middle of the phantom ("center column")
%    It is used that a vertical "hole" aligned in the middle is present in the lower half of the phantom.
%    1. the image intensities below the "center row" along each column are summed 
%    2. the "center column" is the maximum after multiplying the summed
%       intensities with a function to find a symmetric minimum.
%    The "center column" will be used for horizontal cropping of the binary edge image.
%      
% 3. Edge detection in horizontal direction.
%      All edges with a direction significantly different from vertical will be detected. 
%      The result is a binary image. 
%
% 4. Cropping of the binary image in horizontal direction to the "center column" plus and minus 45 mm 
%      Cropping is done for two reasons:
%      1. A more unambiguous assignment of distance between edges in case these edges are curved.
%      2. In the upper left corner a second edge (few millimeter lower than "real" edge) might also be detected.
%         This unwanted edge can be aligned (towards the right) with the real edge in case this real edge is curved, 
%         giving rise to an unwanted peak in the Radon matrix.
%      The cropped region is visualized in the output by vertical blue lines.
%
% 5. Radon transform
%      Lines (or aligned line segments) in the cropped binary image are found by means of a Radon transform.
% 
% 6. Detection of two lines (or aligned line segments)
%      Hereafter, "shift" (either positive or negative) corresponds to the difference between 
%      the "center row" of the phantom and the center row of the image.
%      1. Most pronounced straight line (or aligned line segments), for which
%       - shortest distance between line and center pixel is between 65+shift and 85+shift mm
%       - the point along the line closest to the center pixel is ABOVE the center row of the phantom.
%      2. Most pronounced straight line (or aligned line segments), for which ("shift" has now opposite sign)
%       - shortest distance between line and center pixel is between 65+shift and 85+shift mm
%       - the point along the line closest to the center pixel is BELOW the center row of the phantom
%      The lines (corresponding to edges in the original image) are visualized in the output by red lines.
%
% 7. Calculation of length of phantom. 
%      This length equals the sum of the two "shortest distances".
%      For parallel lines, this corresponds to the distance between the lines.
%      It is always a distance corresponding to a multiple of one pixel, also for rotated and curved edges. 
%      (this is a property of the Radon transform)
%      Each shortest distance (center pixel - edge) is visualized in the output by a red line.
%
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_geomZ
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Frank de Weerd & Joost Kuijer / jpa.kuijer@vumc.nl
% 2009-05-13 / JK
% second version
% ------------------------------------------------------------------------
% JK - 090925 v2.1: modified the algorithm
% - use gradient image instead of binary edge
% - use zero-crossing of derivative to find position of maximum in Radon
% transform. This allows (linear) interpolation.
% ------------------------------------------------------------------------
% JK - 20120807 v2.1: adapted to WAD framework
% ------------------------------------------------------------------------
% JK - 20120807 v2.2: new (v1.1) style action limits
% ------------------------------------------------------------------------
% JK - 20170726 v2.3: rename result 'Geometrie Z' to 'Geometrie Z series'
% ------------------------------------------------------------------------
% JK - 20180913 v2.4: shortened red lines inside image boundary
% ------------------------------------------------------------------------

% produce a figure on the screen or be quiet...
quiet = true;
isInteractive = false;

% version info
my.name = 'WAD_MR_geomZ';
my.version = '2.3';
my.date = '20170726';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );

%gen_object_display( sSeries );
%gen_object_display( sParams );


% select the image within the series
inum = 1; % there should be only 1 image...


% find the image
foundImage = false;
for ii = 1:length( sSeries.instance )
    if ( sSeries.instance(ii).number == inum )
        ci = ii;
        foundImage = true;
        break;
    end
end
if ~foundImage
    WAD_vbprint( [my.name ': Error: could not find image number ' num2str( inum ) ' for geometry Z'], 1 );
    myErrordlg( isInteractive, ['Cannot find configured image number ' num2str( inum ) ' for geometry Z evaluation.'], 'Geometry Z', 'on' );
    return;
end

% display waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating geometry Z' ); end
WAD_vbprint( [my.name ': Calculating geometry Z ...'] );

% read the DICOM image
WAD_vbprint( [my.name ':   loading DICOM image file: ' sSeries.instance(ci).filename ] );
try
    dcmInfo = dicominfo( sSeries.instance(ci).filename );
catch err
    WAD_ErrorMsg( my.name, ['ERROR reading DICOM info from file "' sSeries.instance(ci).filename '")'], err );
    return
end
try
    a = dicomread( dcmInfo );
catch err
    WAD_ErrorMsg( my.name, ['ERROR reading pixel data from DICOM file "' sSeries.instance(ci).filename '")'], err );
    return
end


%warndlg('Testcase CT fantoom: removing bottom part of image');
%a(400:end,:)=0;

% check that pixel size is square
dcmPxSp = dcmInfo.PixelSpacing;
if dcmPxSp(1) ~= dcmPxSp(2)
    WAD_vbprint( [my.name ': Error: pixel size not equal in row and column direction. Currently not supported.'] );
    myErrordlg( isInteractive, 'Pixel size not equal in row and column direction. Currently not supported.', 'Geometry Z', 'on' );
    return;
end
pixelspacing = dcmPxSp(1);

% JK - interpolate pixels to reduce discretisation of length measurement
%WAD_vbprint( [my.name ':  starting interpolation'] );
%a = interp2(a,1,'cubic');
%pixelspacing = pixelspacing / 2;

image_dimension = size(a);
largest_dimension = max(image_dimension);

% 1. find the APPROXIMATE center row
sum_over_columns = zeros( 1, image_dimension(1) );
for i=1:image_dimension(1),
    sum_over_columns(i) = sum(a(i,:));
end
approx_center_row_pix = find_center_row(sum_over_columns,pixelspacing);   

% 2. find the APPROXIMATE center column
sum_over_rows = zeros( 1, image_dimension(2) );
for i=1:image_dimension(2),
      sum_over_rows(i) = sum(a(approx_center_row_pix:image_dimension(1),i));
end
approx_center_column_pix = find_center_column(sum_over_rows,pixelspacing);

%warndlg('Testcase: fix center row/col');
%sim testcase: approx_center_row_pix = 256; approx_center_column_pix = 256;
%CT GE testcase:
%approx_center_row_pix = 221; approx_center_column_pix = 246;

WAD_vbprint( [my.name ':   estimated approximate centre at row ' num2str(approx_center_row_pix) ' and col ' num2str(approx_center_column_pix)] );


% 3. Edge detection
% JK - 090925: use gradient image instead of binary edge image
% bw = edge(a,'Sobel','horizontal');  % 'Prewitt' gives similar results
WAD_vbprint( [my.name ':   calculating gradient image'] );
[gx,gy] = gradient( double(a) );
bw = sqrt( gx.^2 + gy.^2 ); % magnitude of gradient
%figure; colormap(gray(256)); image(bw)


% update waitbar in interactive mode
if isInteractive, waitbar( 0.3, h ); end


% 4. Make a cropped image
%    Consider only the middle part (45 mm left to 45 mm right)
WAD_vbprint( [my.name ':   cropping image'] );
start = round(approx_center_column_pix - 25/pixelspacing);
stop  = round(approx_center_column_pix + 45/pixelspacing);

% Make vertical blue lines to show which part is selected
x_blueline1 = [start,start];
y_blueline1 = [1,image_dimension(1)];
x_blueline2 = [stop,stop];
y_blueline2 = [1,image_dimension(1)];

bw2=bw;
for i=1:start,
    for j=1:image_dimension(1),
        bw2(j,i)=0;
    end
end

for i=stop:image_dimension(2),
    for j=1:image_dimension(1),
        bw2(j,i)=0;
    end
end

% update waitbar in interactive mode
if isInteractive, waitbar( 0.5, h ); end

%figure; colormap(gray(256)); image(bw2)

% 5. Radon transform
WAD_vbprint( [my.name ':   calculating Radon transform'] );
theta = 70:0.5:110;                  % steps of 0.5 degrees are chosen (this is somewhat arbitrarily)
[R,xp] = radon(bw2,theta);

%figure; imshow(R,[]);

% update waitbar in interactive mode
if isInteractive, waitbar( 0.8, h ); end

%figure; imagesc(theta, xp, R); colormap(hot);
%xlabel('\theta (degrees)'); ylabel('x\prime');
%title('R_{\theta} (x\prime)');
%colorbar

% 6. Find the peaks in the Radon matrix
%    An edge in the upper half of the image corresponds to a peak in the lower
%    half of the Radon matrix.
WAD_vbprint( [my.name ':   finding peaks in Radon space'] );
middle_xp_pix = find(xp==0);
ApproxZshift_pix = image_dimension(1)/2 - approx_center_row_pix;    % negative means a downshift

% Find the peak corresponding to the upper edge
StartUpper_pix = middle_xp_pix + round(ApproxZshift_pix) + round(65/pixelspacing);
StopUpper_pix  = middle_xp_pix + round(ApproxZshift_pix) + round(85/pixelspacing);
[UpperDistance_pix, Theta_Upper_deg] = find_the_peak(R,xp,theta,StartUpper_pix,StopUpper_pix);

% Find the peak corresponding to the lower edge
StartLower_pix = middle_xp_pix + round(ApproxZshift_pix) - round(85/pixelspacing);
StopLower_pix  = middle_xp_pix + round(ApproxZshift_pix) - round(65/pixelspacing);
[LowerDistance_pix, Theta_Lower_deg] = find_the_peak(R,xp,theta,StartLower_pix,StopLower_pix);

% 7. Calculate the size of the phantom along its longitudinal axis
Zsize_pix = UpperDistance_pix - LowerDistance_pix;

lengthZ_mm = Zsize_pix * pixelspacing;
rotationSAG_deg = 0.5 .* (Theta_Upper_deg + Theta_Lower_deg) - 90;

WAD_resultsAppendFloat( 1, lengthZ_mm, 'Lengte', 'mm', 'Geometrie Z' );
WAD_resultsAppendFloat( 1, rotationSAG_deg, 'Rotatie', 'graden', 'Geometrie Z' );

%handles.results.lengthZ_mm

% close waitbar in interactive mode
if isInteractive, close( h ), end


% In the matlab help, it can be found that the center pixel of image I in the Radon transformation is defined to be floor((size(I)+1)/2)
CenterPixel = floor((size(a)+1)/2);

[x_edge_upper, y_edge_upper] = draw_the_edge(CenterPixel,largest_dimension./2,UpperDistance_pix,Theta_Upper_deg);
[x_edge_lower, y_edge_lower] = draw_the_edge(CenterPixel,largest_dimension./2,LowerDistance_pix,Theta_Lower_deg);
[x_distance_upper, y_distance_upper] = draw_the_distance(CenterPixel,UpperDistance_pix,Theta_Upper_deg);
[x_distance_lower, y_distance_lower] = draw_the_distance(CenterPixel,LowerDistance_pix,Theta_Lower_deg);

% Draw all lines in the images
% create figure
if quiet 
    fig_visible = 'off';
else
    fig_visible = 'on';
end

% create figure
hFig1 = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Geometry Z' );
colormap( gray(256) );
imagesc( a );
axis image
axis square
axis off
title( [ 'series ' num2str(sSeries.number) ' - image ' num2str(sSeries.instance(ci).number)], 'Interpreter', 'none' );

%figure; colormap(gray(256)); imagesc(a);

hold on

plot(x_edge_upper,y_edge_upper,'r-');
plot(x_distance_upper,y_distance_upper,'r-');
plot(x_edge_lower,y_edge_lower,'r-');
plot(x_distance_lower,y_distance_lower,'r-');
plot(x_blueline1,y_blueline1,'b-');
plot(x_blueline2,y_blueline2,'b-');

hold off


% Write figure to level 2
WAD_resultsAppendString( 2, ['Analysis on series: ' num2str(sSeries.number) ' / image: ' num2str(inum) ], 'Geometrie Z series' )
WAD_resultsAppendFigure( 2, hFig1, 'geomZ_fitted', 'Geometrie Z: randdetectie' );
if quiet
    % delete non-visible image
    delete( hFig1 );
end


% create figure
hFig2 = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'SNR / Ghosting' );
colormap( gray(256) );
image( bw )
axis image
axis square
axis off
title( [ 'series ' num2str(sSeries.number) ' - image ' num2str(sSeries.instance(ci).number)], 'Interpreter', 'none' );
%figure; colormap(gray(2)); image(bw)

hold on

plot(x_edge_upper,y_edge_upper,'r-');
plot(x_distance_upper,y_distance_upper,'r-');
plot(x_edge_lower,y_edge_lower,'r-');
plot(x_distance_lower,y_distance_lower,'r-');
plot(x_blueline1,y_blueline1,'b-');
plot(x_blueline2,y_blueline2,'b-');

hold off;

% Write figure to level 2
WAD_resultsAppendFigure( 2, hFig2, 'geomZ_thresholded', 'Geometrie Z: randdetectie (edge image)' );
if quiet
    % delete non-visible image
    delete( hFig2 );
end



%%%%%%%%%%%%%%%%%%%%%%% SUB-FUNCTION %%%%%%%%%%%%%%%%%%%%%%% 
function [distance_pix, Theta_deg] = find_the_peak(R,xp,theta,start_pix,stop_pix)
% JK - 090925: use zero-crossing of derivative instead of maximum.
%figure; imshow(R(start_pix:stop_pix,:),[]);

%[MaxPerTheta_vector LocationMaxPerTheta_vector] = max(R(start_pix:stop_pix,:));
[GlobalMax Theta_pix] = max(max(R(start_pix:stop_pix,:)));

Theta_deg = theta(Theta_pix);
%dummy = LocationMaxPerTheta_vector(Theta_pix);
%LocationMax_pix = dummy + start_pix - 1;

% JK - 090925: take the pixels at the angle where the maximum is located
lineAtTheta = R(start_pix:stop_pix,Theta_pix);
%figure; plot(lineAtTheta);
%figure; plot(gradient(lineAtTheta));

% find the position of the maximum
zerocross_pix = find_zerocrossing_pix( gradient(lineAtTheta) );
LocationMax_pix = zerocross_pix + start_pix - 1;

%distance_pix = xp(LocationMax_pix);
distance_pix = interp1( xp, LocationMax_pix);


%%%%%%%%%%%%%%%%%%%%%%% SUB-FUNCTION %%%%%%%%%%%%%%%%%%%%%%%
function centerpixel = find_center_row(linesum,pixelspacing)

number_of_rows = length(linesum);

fx = gradient(linesum);

%figure; plot(linesum);
%figure; plot(fx);

% find smallest element larger than zero
n=0;
for i=1:number_of_rows,
   if(linesum(i) > 0)
      n = n + 1;
      if( n == 1) 
          smallest = linesum(i);
      elseif (linesum(i) < smallest)
             smallest = linesum(i);    
      end    
   end    
end

% make zero elements equal to smallest
for i=1:number_of_rows,
   if (linesum(i)==0)
       linesum(i)= smallest;
   end    
end

% laat een mask van plus min 10 mm lopen
bandwidth = round(10/pixelspacing);

test_value_left  = zeros( 1, number_of_rows );
test_value_right = zeros( 1, number_of_rows );
for i = 1 : number_of_rows
   test_value_left(i) = 0;
   test_value_right(i) = 0;
   for j= 1:bandwidth,   
     if (i+j > number_of_rows)
         value_right = smallest;
     else
         value_right = linesum(i+j);
     end  
     if (i-j < 1)
         value_left = smallest;
     else    
         value_left = linesum(i-j);
     end    
     ratio_left = value_right / value_left;
     ratio_right = value_left / value_right;     
     test_value_left(i) = test_value_left(i) + ratio_left;
     test_value_right(i) = test_value_right(i) + ratio_right;
   end   
end

linesum_left  = zeros( 1, number_of_rows );
linesum_right = zeros( 1, number_of_rows );
for i=1:number_of_rows;
   linesum_left(i) = fx(i)*test_value_left(i);
   linesum_right(i) = fx(i)*test_value_right(i);
end

% skip some pixels near edge of image...
skip_pix = 10;
linesum_left(1:skip_pix) = 0;
linesum_left(number_of_rows-skip_pix:number_of_rows) = 0;
linesum_right(1:skip_pix) = 0;
linesum_right(number_of_rows-skip_pix:number_of_rows) = 0;

%figure; plot(test_value_left);
%figure; plot(test_value_right);
%figure; plot(linesum_left);
%figure; plot(linesum_right);

% find the upper edge
[maximum loc_max] = max(linesum_left);

% find the lower edge
[minimum loc_min] = min(linesum_right);

centerpixel = round((loc_min + loc_max)/2);

%%%%%%%%%%%%%%%%%%%%%%% SUB-FUNCTION %%%%%%%%%%%%%%%%%%%%%%%
function centerpixel = find_center_column(linesum,pixelspacing)

number_of_columns = length(linesum);

%figure; plot(linesum);

% find smallest element larger than zero
n=0;
for i=1:number_of_columns,
   if(linesum(i) > 0)
      n = n + 1;
      if( n == 1) 
          smallest = linesum(i);
      elseif (linesum(i) < smallest)
             smallest = linesum(i);    
      end    
   end    
end

% make zero elements equal to smallest
for i=1:number_of_columns,
   if (linesum(i)==0)
       linesum(i)= smallest;
   end    
end

% laat een mask van plus min 30 mm lopen
bandbreedte = round(30/pixelspacing);

test_waarde = zeros( 1, bandbreedte );
for i = bandbreedte + 1 : number_of_columns - bandbreedte - 1,
   test_waarde(i) = 0;
   for j= 1:bandbreedte,   
     som = ((linesum(i-j) + linesum(i+j))/2) - linesum(i);
     ratio = linesum(i-j) / linesum(i+j);
     if (ratio > 1)
         ratio = 1/ratio;
     end    
     som = som * ratio;
     test_waarde(i) = test_waarde(i) + som;
   end
end

for i = number_of_columns - bandbreedte : number_of_columns,
   test_waarde(i) = 0;
end
       
%figure; plot(test_waarde);

% find the center
[maximum loc_max] = max(test_waarde);

centerpixel = loc_max;



%%%%%%%%%%%%%%%%%%%%%%%% SUB-FUNCTION %%%%%%%%%%%%%%%%%%%%%
% find zero-crossing in a 1D array, supposed to be the 2nd derivative of
% the image intensity (in the Radon transform)
% Return value is 0 when crossing is not found.
function zerocross_pix = find_zerocrossing_pix( x )
% search the zero crossing only between the maximum and the minimum
[~, max_i] = max( x );
[~, min_i] = min( x ); % min should have higher index than max

% check if we should be able to find a proper zero crossing
if ( x(max_i) < 0 ) || ( x(min_i) > 0 )
    fprintf( 2, 'ERROR in SQ_MR_geomZ: cannot find edge. No zero-crossing of 2nd derivative.' );
    zerocross_pix = 0;
    return
end
% find the index where the sign has changed
for ii = max_i:min_i
    if x(ii) < 0, break, end
end
% interpolate between pixels
zerocross_pix = (ii-1) + x(ii-1) ./ ( x(ii-1) - x(ii) );





%%%%%%%%%%%%%%%%%%%%%%%% SUB-FUNCTION %%%%%%%%%%%%%%%%%%%%%
% Turn the found edge into a red line
function [x,y] = draw_the_edge(CenterPixel,largest_dimension,Distance_pix,Theta_deg)

x(1) = CenterPixel(2) - largest_dimension .* sin(2*pi*Theta_deg/360);
x(2) = CenterPixel(2) + largest_dimension .* sin(2*pi*Theta_deg/360);
y(1) = CenterPixel(1) - largest_dimension .* cos(2*pi*Theta_deg/360);
y(2) = CenterPixel(1) + largest_dimension .* cos(2*pi*Theta_deg/360);

x = x + Distance_pix .* cos(2*pi*Theta_deg/360);
y = y - Distance_pix .* sin(2*pi*Theta_deg/360);


%%%%%%%%%%%%%%%%%%%%%%%% SUB-FUNCTION %%%%%%%%%%%%%%%%%%%%%
% Make a distance line
function [x,y] = draw_the_distance(CenterPixel,Distance_pix,Theta_deg)

x(1)= CenterPixel(2);
x(2)= CenterPixel(2) + Distance_pix .* cos(2*pi*Theta_deg/360);
y(1)= CenterPixel(1);
y(2)= CenterPixel(1) - Distance_pix .* sin(2*pi*Theta_deg/360);
