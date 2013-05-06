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

function [magnitude, phase] = WAD_MR_B0_readPhilipsDoubleEcho( i_iSeries, sSeries, sParams, sLimits )
% Import function for BO uniformity Philips double echo FFE images. 
% Acquisition must be single slice, with magnitude and phase images.
%
% This is a import function to be called from WAD_MR_B0_uniformity()
%
% Configuration name for the <params><type> field:
% PhilipsDoubleEcho
%
% Known limitations:
% - Needs Explicit DICOM files. TODO: check type of field, if uint8 convert
%   it to whatever is expected.
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_B0_uniformity_SiemensPhaseDifference
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


% ----------------------
% GLOBALS
% ----------------------
%global WAD

% version info
my.name = 'WAD_MR_B0_readPhilipsDoubleEcho';
my.version = '0.95';
my.date = '20120813';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );


% output arguments
magnitude = [];
phase = [];


% ----------------------------------------------------
% check image type, get dicom header of first file
% ----------------------------------------------------
fname = sSeries.instance( 1 ).filename;
WAD_vbprint( [my.name ':   Check type of B0 map... reading DICOM header of file ' fname ] );
info = dicominfo( fname );


if isfield( info, 'Private_2001_1020' ) &&  strfind( info.Private_2001_1020, 'FFE' )
    % Philips product FFE sequence (hopefully with double echo and phase images)
    WAD_vbprint( [my.name ':   Detected Philips double echo FFE.'] );
else
    WAD_vbprint( [my.name ':   Could not detect Philips double echo FFE. Private_2001_1020 not equal to "FFE"'] );
    error( 'Error during import of phase images.' )
end

WAD_vbprint( [my.name ':   Setting type of B0 map to Philips double echo with phase images.'] );
% Philips puts all imagese in one series:
% - first the 2 magnitude images
% - then the 2 phase images
if length( sSeries.instance ) ~= 4
    WAD_vbprint( [my.name ':   ERROR: B0 map series does not have 4 images. Skipping analysis'] );
    error( 'Error during import of phase images.' )
end

% magnitude series / image
mci = 1;
% phase series / image
pci = 3; pci2 = 4; % image number of phase images of first and second echo


% ----------------------------------------------------
% read DICOM images
% ----------------------------------------------------
magnitude.filename = sSeries.instance( mci ).filename;
magnitude.info  = dicominfo( magnitude.filename );
magnitude.image = double( dicomread( magnitude.info ) );

phase.filename  = sSeries.instance( pci ).filename;
phase.info      = dicominfo( phase.filename );
phase.image     = double( dicomread( phase.info ) );

% read second phase image, we need it for the scaling factor
phase2.filename  = sSeries.instance( pci2 ).filename;
phase2.info      = dicominfo( phase2.filename );
phase2.image     = double( dicomread( phase2.info ) );

% conversion phase map from pixel values to radians
% Philips has the RescaleSlope field defined, and needs an
% additional factor 1000
if isfield( phase2.info, 'RescaleSlope' )
    factor = phase2.info.RescaleSlope / 1000.0;
    offset = 0; % matlab reads the offset already from RescaleIntercept
else
    % don't know what to do without the rescale slope...
    WAD_vbprint( [my.name ':   ERROR: phase image does not have RescaleIntercept defined. Skipping analysis'] );
    error( 'Error during import of phase images.' )
end

% subtract the first image
phase.image = phase2.image - phase.image;

% convert from phase image from pixel values to radians
phase.dPhi_rad = phase.image * factor - offset;

% get delta-TE from header of both phase images
phase.dTE = phase2.info.EchoTime - phase.info.EchoTime;
WAD_vbprint( [my.name ':   Getting delta-TE from phase images: ' num2str(phase.dTE) ' ms'] );
