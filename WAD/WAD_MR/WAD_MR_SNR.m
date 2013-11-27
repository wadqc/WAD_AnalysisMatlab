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

function WAD_MR_SNR( i_iSeries, sSeries, sParams )
% Evaluate SNR, ghosting and image uniformity of the central slice
%
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_SNR
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2008-10-24 / JK
% first version
% ------------------------------------------------------------------------
% 2012-08-09 adapted to WAD
% ------------------------------------------------------------------------

% produce a figure on the screen or be quiet...
quiet = true;
isInteractive = false;

% ----------------------
% GLOBALS
% ----------------------
global WAD

% version info
my.name = 'WAD_MR_SNR';
my.version = '1.1';
my.date = '20130904';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );



% ---------------------------------------------
% select the plain water image without features
% ---------------------------------------------
% default: use configured slice of current series
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



% ---------------------------------------------
% find the image
% ---------------------------------------------
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



% ---------------------------------------------
% do the evaluation...
% ---------------------------------------------
% display waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating SNR...' ); end

WAD_vbprint( [my.name ':   Calculating centre coordinates ...'] );

if ~isfield( sParams, 'interpolPower' ) || isempty( sParams.interpolPower )
    sParams.interpolPower = 0; % default setting: no interpolation for calculation of centre of phantom
end
WAD_vbprint( [my.name ':   Interpolation set to 2 ^ ' num2str(sParams.interpolPower) '. This is configurable in <params> <interpolPower>' ] );

% SNR needs the centre coordinates, which are calculated by WAD_MR_privateSizePos_pix
try
    [diameter_pix, centre_pix] = WAD_MR_privateSizePos_pix( sSeries.instance(ci), sParams, quiet );
catch err
    WAD_ErrorMsg( my.name, 'ERROR calculating centre coordinates.', err );
    return
end
WAD_vbprint( [my.name ':   Centre location at ' num2str(centre_pix)] );

% configured parameters for ROI's
% SNR needs distance of background ROI's from phantom centre
if ~isfield( sParams, 'backgroundROIshift' ) || isempty( sParams.backgroundROIshift )
    % no ROI shift configured, use default
    sParams.backgroundROIshift = WAD.const.defaultBackgroundRoiShift;
    WAD_vbprint( [my.name ':   No parameter <backgroundROIshift> configured, using default value = ' num2str(sParams.backgroundROIshift) ' mm'] );
end
WAD_vbprint( [my.name ':   Configured ROI shift = ' num2str(sParams.backgroundROIshift) ' mm'] );

if ~isfield( sParams, 'ROIradius' ) || isempty( sParams.ROIradius )
    % no ROI radius configured, use default
    sParams.ROIradius = WAD.const.defaultRoiRadius;
    WAD_vbprint( [my.name ':   No parameter <ROIradius> configured, using default value = ' num2str(sParams.ROIradius) ' mm'] );
end
WAD_vbprint( [my.name ':   Configured ROI radius = ' num2str(sParams.ROIradius) ' mm'] );

if ~isfield( sParams, 'backgroundROIsize' ) || isempty( sParams.backgroundROIsize )
    % no ROI radius configured, use default
    sParams.backgroundROIsize = WAD.const.defaultBackgroundRoiSize;
    WAD_vbprint( [my.name ':   No parameter <backgroundROIsize> configured, using default value = ' num2str(sParams.backgroundROIsize) ' mm'] );
end
WAD_vbprint( [my.name ':   Configured ROI radius = ' num2str(sParams.backgroundROIsize) ' mm'] );


if isInteractive, waitbar( 0.5, h ); end

% ---------------------------------------------
% calculate the SNR and ghosting and percentage image uniformity (PIU)
% ---------------------------------------------
[SNR, ghostRow_percent, ghostCol_percent, imageUniformity_percent, hFigSNR] = WAD_MR_privateSNR_ghost( sSeries.instance(ci), centre_pix, sParams, quiet );

% factor 0.655 corrects for reduced noise in background of magnitude image.
% See Henkelman. Not exact for phased array coils, e.g. 8-channnel should
% be ~0.70
SNR_henk = SNR * 0.655;

WAD_resultsAppendFloat( 1, SNR_henk, 'SNR', [], 'Combined coils' );
WAD_resultsAppendFloat( 1, ghostRow_percent, 'Ghosting', '%', 'Row' );
WAD_resultsAppendFloat( 1, ghostCol_percent, 'Ghosting', '%', 'Col' );
% present results together with phase encoding direction
try
    info = dicominfo( sSeries.instance(ci).filename );
    if isfield( info, 'InPlanePhaseEncodingDirection' )
        WAD_resultsAppendString( 1, info.InPlanePhaseEncodingDirection, 'Fase-coderingsrichting' );
    end
catch err
    WAD_ErrorMsg( my.name, ['ERROR getting phase enc. dir. from file: "' sSeries.instance(ci).filename '"'], err );
end
    
% image uniformity
WAD_resultsAppendFloat( 1, imageUniformity_percent, 'Uniformity', '%', 'Image' );
WAD_resultsAppendString( 2, ['SNR on series: ' num2str(sSeries.number) ' / image: ' num2str(inum)], 'SNR' );

WAD_resultsAppendFigure( 2, hFigSNR, 'SNR_ROI', 'ROIs for SNR and ghosting' );

if quiet
    % delete non-visible image
    delete( hFigSNR );
end

% close waitbar
if isInteractive, close( h ), end
