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

function WAD_MR_B0_uniformity( i_iSeries, sSeries, sParams )
% Calculate BO uniformity from a double echo phase difference.
% Acquisition must be single slice.
%
% Algorithm:
% - load dicom images using a vendor-specific "import" function
%   + name of import function must be configured as parameter 
% - find centre and diameter of phantom using WAD_MR_privateSizePos_pix
% - unwrap phase images
% - convert phase pixel value to B0 map using delta-TE
% - Optional TODO: low-pass filter to lower noise, or use ROI analysis.
% - find min / max values, difference is result (in ppm)
%
% Known limitations:
% - Needs Explicit DICOM files. TODO: check type of field, if uint8 convert
%   it to whatever is expected.
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_B0_uniformity
% 
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2009-12-22 / JK
% first version implemented from Eline Verwer's code.
% ------------------------------------------------------------------------
% 2010-04-20 / JK
% V0.94: added support for Philips double-echo GRE
% ------------------------------------------------------------------------
% 2012-08-13 / JK
% V0.95
% - adapted to WAD framework
% - import of phase images in separate "import" function, configurable
%   through the <type> parameter. The actual function name gets a prefix
%   "WAD_MR_B0_read".
% ------------------------------------------------------------------------
% 20131127 / JK
% V1.1
% - new (v1.1) style action limits
% ------------------------------------------------------------------------

% ----------------------
% GLOBALS
% ----------------------
%global WAD

% version info
my.name = 'WAD_MR_B0_uniformity';
my.version = '1.1';
my.date = '20131127';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );



quiet = 1;
% create figure for B0 map on screen
if quiet 
    fig_visible = 'off';
else
    fig_visible = 'on';
end
isInteractive = false;



% ----------------------------------------------------
% defines for analysis
% ----------------------------------------------------
szROI = 0.95; % diameter of ROI relative to diameter of phantom
ignoreTop = 0.8; % top part of ROI to be ignored (air bubble), relative to ROI size



% display waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating B0 uniformity...' ); end


% check param for import function
if ~isfield( sParams, 'type' ) || isempty( sParams.type )
    WAD_vbprint( [my.name ' : Import function type not defined in configuration!' ], 1 );
    return
end    
    
% check if type is function (in a .m file) with configured name exists
importFuncName = [ 'WAD_MR_B0_read' sParams.type ];
if exist( importFuncName, 'file' ) ~= 2
    % funtion does not exist
    WAD_vbprint( [my.name ': ERROR: Configured import function named "' importFuncName '" does not exist!' ], 1 );
    return
end
% construct function handle
importfh = str2func( importFuncName );

% import images
try
    [magnitude, phase] = importfh( i_iSeries, sSeries, sParams );
catch err
    WAD_ErrorMsg( my.name, 'ERROR during reading/conversion of phase map.', err );
    return
end

if isempty( magnitude ) || isempty( phase )
    % didn't get results back
    WAD_vbprint( [my.name ': no magnitude or phase data read for quantification.' ], 1 );
    return
end

% check type of data, options are:
% - dPhi_rad: (wrapped) phase in radians [default]
% - dB0_ppm : B0 in ppm
if ~isfield( phase, 'type' ) || isempty( phase.type )
    % apply default
    phase.type = 'dPhi_rad';
end

% consistency check
if ~isfield( phase, phase.type )
    % image data not consistent with give data type
    WAD_vbprint( [my.name ': consistency check failed! Phase type ' phase.type ' but field phase.' phase.type ' doesn''t exist.' ], 1 );
    return
end


% update waitbar
if isInteractive, waitbar( 0.2, h ); end


% ----------------------------------------------------
% find centre and diameter of phantom
% ----------------------------------------------------
% vind fantoom in magnitudeplaatje
interpolPower=0;
quiet=1; % no image from geometry fit

% TO DO: WAD_MR_sizePos_pix reads the DICOM image again... avoid double read
% action...
[diameter_pix, centre_pix ] = WAD_MR_privateSizePos_pix( magnitude, interpolPower, quiet );

% update waitbar
if isInteractive, waitbar( 0.5, h ); end

% definieer masker
axis_x = floor( szROI * diameter_pix(1) / 2 );
axis_y = floor( szROI * diameter_pix(2) / 2 );

[phase.masked, mask] = ROImask( axis_x, axis_y, centre_pix, phase.(phase.type), 0 );

magnitude.masked = magnitude.image .* mask;

% ----------------------------------------------------
% haalt bovenste stuk fantoom af omdat daar afwijkende geometrie,
% anders gaat daarop berekening B0 uniformiteit en fase unwrapping mis
% LET OP: centre_pix heeft x en y omgedraaid... why??
% ----------------------------------------------------
phasemask(:,:) = mask(:,:);
ignoreTopRows = floor( centre_pix(2) - ignoreTop*axis_x );
phasemask( 1:ignoreTopRows, : ) = 0;

phase.masked = phase.masked .* phasemask;

% update waitbar
if isInteractive, waitbar( 0.6, h ); end

% ----------------------------------------------------
% unwrappen
% ----------------------------------------------------
% procedure start in centerpixel van fantoom (aanname: geen wrapping nabij
% center pixel)
x_pix=floor(centre_pix(1));
y_pix=floor(centre_pix(2));

% unwrapping fasehoek, en conversie naar B0
if strcmp( phase.type, 'dPhi_rad' )
    phase.unwrapped = unwrap2D( phase.masked, [x_pix,y_pix]);
    phase.maskedandunwrapped = phase.unwrapped .* phasemask;
    % update waitbar
    if isInteractive, waitbar( 0.8, h ); end

    % ----------------------------------------------------
    % bereken B0
    % ----------------------------------------------------
    gamma = 267513; %42576;  % gyromatric frequency in rad/s*1/T
    magnet_T = phase.info.MagneticFieldStrength;  % in Tesla

    dB0_T = phase.maskedandunwrapped / (gamma .* phase.dTE); % in Tesla
    dB0_ppm = dB0_T / magnet_T * 1000000; % in ppm
else
    % For B0 map: just apply the mask
    dB0_ppm = phase.dB0_ppm .* phasemask;
end

% write B0 map to calculations log file
hFig = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'B0 map [ppm]' );
imshow( dB0_ppm, [] ); % in ppm
colormap(jet);
axis image
axis square
axis off
title('B0 uniformity [ppm]', 'Interpreter', 'none');
colorbar

WAD_resultsAppendString( 2, ['B0 map calculated from series: ' num2str(sSeries.number) ], 'B0 uniformiteit' );
WAD_resultsAppendFigure( 2, hFig, 'B0map', 'B0 uniformiteit' );

if quiet
    % delete non-visible image
    delete( hFig );
end

% update waitbar
if isInteractive, waitbar( 0.9, h ); end

% ----------------------------------------------------
% bereken uniformiteit
% ----------------------------------------------------
matrixsize_phase = size( phase.dB0_ppm );

smallest = +1.0E99; % huge
largest  = -1.0E99; % negative huge

for i=1:matrixsize_phase(1)
    for j=1:matrixsize_phase(2)
        if phasemask(i,j) == 1
            if phase.dB0_ppm(i,j) < smallest
                smallest = phase.dB0_ppm(i,j);
            end
            if phase.dB0_ppm(i,j) > largest
                largest = phase.dB0_ppm(i,j);
            end
        end
    end
end

% update waitbar
if isInteractive, waitbar( 1.0, h ); end


% ----------------------------------------------------
% final result: difference in ppm
% ----------------------------------------------------
B0_uniformity_ppm = largest - smallest; % in ppm
WAD_resultsAppendFloat( 1, B0_uniformity_ppm, 'Uniformity', 'ppm', 'B0' );

% log file
WAD_vbprint( [my.name ':   B0 uniformity = ' num2str(B0_uniformity_ppm) ' ppm'] );


% close waitbar in interactive mode
if isInteractive, close( h ), end

return
end



function [B,M] = ROImask(a,b,cent,I,valfill)
% -------------------------------------------------------------------------
% Creates an elliptical mask defined by paramaters a, b and cent. Multiples
% this mask to I and fills all pixels outside ellipse with valfill
% -------------------------------------------------------------------------
centx = cent(1);
centy = cent(2);
[numr,numc] = size(I);
[x,y] = meshgrid( 1:numc, 1:numr );
M = double( ((x-centx).^2) ./ a.^2 + ((y-centy).^2) ./ b.^2 <= 1 );
B = M .* I + ( 1.0 - M ) .* valfill;
end



% -------------------------------------------------------------------------
function [image_out] = unwrap2D(image_in, center)
% in MatLab werkt de functie "unwrap" alleen van links naar rechts
% dit gaat mis als de waarde in het eerste pixel niet correct is
% aangezien aan de randen meer ruis te verwachten is, is ervoor gekozen om
% vanuit het centrum van het fantoom te unwrap-en.
% Allereest verticaal vanuit het centrum naar boven en naar beneden.
% Vervolgens vanuit deze ge-unwrapte kolom per element steeds naar links en naar rechts 
% -------------------------------------------------------------------------
image_out=image_in;
orientation=1;

size_image=size(image_in);

x=center(1);
y=center(2);

col_end   = image_in(x:size_image(1),y); % laatste deel kolom selecteren zodat center pixel eerste pixel
col_start = flipud(image_in(1:x,y));     % eerste deel kolom omkeren zodat centerpixel meest eerste pixel

% beide delen unwrappen:
result_end=unwrap(col_end,[],orientation);
result_start=unwrap(col_start,[],orientation);

%ge-unwrapte delen weer invoegen in uiteindelijke image:
image_out(x:size_image(1),y)=result_end(:,:);
image_out(1:x-1,y)=flipud(result_start(2:x,1));

% in x-richting:
for count=1:size_image(1)
    image_out=unwrap_line(image_out(:,:),count,y,size_image,2);
end

end




% -------------------------------------------------------------------------
function image_out = unwrap_line(image_out,x,y,size_image,orientation)
% -------------------------------------------------------------------------
row_end   = image_out( x, y:size_image(2) ); % laatste deel rij selecteren zodat center pixel meest links
row_start = fliplr( image_out( x, 1:y ) );   % eerste deel rij omkeren zodat centerpixel meest links

% beide delen unwrappen:
result_end   = unwrap( row_end,   [], orientation);
result_start = unwrap( row_start, [], orientation);

% ge-unwrapte delen weer invoegen in uiteindelijke image:
image_out(x, y:size_image(2))  = result_end( :,: );
image_out(x, 1:y-1          )  = fliplr( result_start( 1, 2:y ) );
end
