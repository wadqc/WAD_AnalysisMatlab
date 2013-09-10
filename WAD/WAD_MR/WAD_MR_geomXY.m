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

function WAD_MR_geomXY( i_iSeries, sSeries, sParams, sLimits )
% Calculate the diameter along horizontal and vertical axis of a plain water image
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_geomXY
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2008-10-24 / JK
% first version
% ------------------------------------------------------------------------
% 2008-10-24 / JK adapted to WAD
% ------------------------------------------------------------------------


% produce a figure on the screen or be quiet...
quiet = true;
isInteractive = false;

% ----------------------
% GLOBALS
% ----------------------
global WAD

% version info
my.name = 'WAD_MR_geomXY';
my.version = '1.1';
my.date = '20130904';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );



% ---------------------------------------------
% select the plain water image without features
% ---------------------------------------------
% default: use plain water slice in 11-slice ACR protocol
inum = 7;
% may be overruled by series config...
if isfield( sParams, 'image' ) && ~isempty( sParams.image )
    inum = sParams.image;
    % handle specials...
    if isequal( inum, WAD.const.firstInSeries )
        inum = 1;
    elseif isequal( inum, WAD.const.lastInSeries )
        inum = length( sSeries.instance );
    end
end
% is it just one slice? then we use it...
if length( sSeries.instance ) == 1
    inum = 1;
end


% find the image
foundImage = false;
for ii = 1:length( sSeries.instance )
    if sSeries.instance(ii).number == inum
        ci = ii;
        foundImage = true;
        break;
    end
end
if ~foundImage
    WAD_vbprint( [my.name ': Error: could not find configured image ' num2str( inum ) ' for geometry X Y evalutation'] );
    myErrordlg( isInteractive, ['Cannot find configured image ' num2str( inum ) ' for geometry evaluation.'], 'Geomety X and Y', 'on' );
    return;
end

% display waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating Geometry X and Y...' ); end

% do the evaluation...
% define the interpolation if not defined as parameter in the config file
WAD_vbprint( [my.name ':   calculating diameter and centre coordinates ...'] );
if ~isfield( sParams, 'interpolPower' ) || isempty( sParams.interpolPower )
    sParams.interpolPower = 1; % default setting: use half the pixel size, goes slower but should be a little more precise.
end
WAD_vbprint( [my.name ':   Interpolation set to 2 ^ ' num2str(sParams.interpolPower) '. This is configurable in <params> <interpolPower>' ] );

try
    [diameter_pix, centre_pix, hFigGeomXY] = WAD_MR_privateSizePos_pix( sSeries.instance(ci), sParams, quiet );
catch err
    WAD_ErrorMsg( my.name, 'ERROR calculating diameter and centre coordinates.', err );
    return
end

WAD_vbprint( [my.name ':   centre location at ' num2str(centre_pix)] );

% get the pixel size from DICOM header
try
    dcmInfo = dicominfo( sSeries.instance(ci).filename );
catch err
    WAD_ErrorMsg( my.name, 'ERROR reading DICOM image header for SNR.', err );
    return
end

pixelSpacing = dcmInfo.PixelSpacing;

% convert diameter from pixels to mm
% !!!! TO DO: check X and Y indices !!!!
% why is the index reversed from first index -> y and second index -> x?
diameterX_mm = diameter_pix(1) .* pixelSpacing(2); % ???
diameterY_mm = diameter_pix(2) .* pixelSpacing(1); % ???

WAD_resultsAppendString( 2, ['Analysis on series: ' num2str( sSeries.number ) ' / image: ' num2str( inum ) ], 'Geometrie XY' );
WAD_resultsAppendString( 2, ['Centre location at ' num2str(centre_pix)], 'Geometrie XY' );

WAD_resultsAppendFigure( 2, hFigGeomXY, 'geomXY', 'Geometrie X en Y: randdetectie' );

if quiet
    % delete non-visible image
    delete( hFigGeomXY );
end

WAD_resultsAppendFloat( 1, diameterX_mm, 'Diameter', 'mm', 'Geometrie X', sLimits, 'diameterX_mm' );
WAD_resultsAppendFloat( 1, diameterY_mm, 'Diameter', 'mm', 'Geometrie Y', sLimits, 'diameterY_mm' );


% close waitbar in interactive mode
if isInteractive, close( h ), end

return
