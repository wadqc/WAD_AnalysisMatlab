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

function [magnitude, phase] = WAD_MR_B0_readPhilips_B0map( i_iSeries, sSeries, sParams )
% Import function for B0 uniformity Philips clinical science key B0 map. 
% Acquisition must be single slice, with one magnitude and one phase image.
%
% This is a import function to be called from WAD_MR_B0_uniformity()
%
% Configuration name for the <params><type> field:
% Philips_B0map
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
% 20131127 / JK
% V1.1
% - new (v1.1) style action limits
% ------------------------------------------------------------------------
% 20140212 / JK
% V1.1.1
% Private fields are class uint8 and in one column for implicit DICOM, and class char and one row for explicit DICOM
% char(info.Private_2001_1020(:))' converts both to class char and one row.
% ------------------------------------------------------------------------
% 20140729 / JK
% V2.1.1
% Converted to Philips B0 map with clinical science key (B0 map option)
% Unit of phase map is [Hz]
% ------------------------------------------------------------------------
% 20150901 / JK
% V2.1.2
% Fix: wrong image number if received in random order.
% ------------------------------------------------------------------------
% 20170721 / JK
% V2.2
% Adapted to WAD2
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
%global WAD

% version info
my.name = 'WAD_MR_B0_readPhilips_B0map';
my.version = '2.2';
my.date = '20170721';
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

% Private fields are class uint8 and in one column for implicit DICOM, and class char and one row for explicit DICOM
% char(info.Private_2001_1020(:))' converts both to class char and one row.
if isfield( info, 'Private_2001_1020' ) &&  strfind( char(info.Private_2001_1020(:))', 'FFE' )
    % Philips product FFE sequence (hopefully with double echo and phase images)
    WAD_vbprint( [my.name ':   Detected Philips FFE.'] );
else
    WAD_vbprint( [my.name ':   Could not detect Philips double echo FFE. Private_2001_1020 not equal to "FFE"'] );
    error( 'Error during import of phase images.' )
end

WAD_vbprint( [my.name ':   Setting type of B0 map to Philips B0 map with phase images.'] );
% Philips puts all images in one series:
% - first the magnitude image
% - then the phase difference image
if length( sSeries.instance ) ~= 2
    WAD_vbprint( [my.name ':   ERROR: B0 map series does not have 2 images. Skipping analysis'] );
    error( 'Error during import of phase images.' )
end

% ---------------------------------------------
% find the image
% ---------------------------------------------
foundImage = false;
for ii = 1:length( sSeries.instance )
    if sSeries.instance(ii).number == 1
        mci = ii;
        foundImage = true;
        break;
    end
end
if ~foundImage
    WAD_vbprint( [my.name ': Error: could not find magnitude image (#1) ' num2str( inum ) ' for Philips B0 map'] );
    return;
end

% find phase image
foundImage = false;
for ii = 1:length( sSeries.instance )
    if sSeries.instance(ii).number == 2
        pci = ii;
        foundImage = true;
        break;
    end
end
if ~foundImage
    WAD_vbprint( [my.name ': Error: could not find phase image (#2) ' num2str( inum ) ' for Philips B0 map'] );
    return;
end


% ----------------------------------------------------
% read DICOM images
% ----------------------------------------------------
magnitude.filename = sSeries.instance( mci ).filename;
magnitude.info  = dicominfo( magnitude.filename );
magnitude.image = double( dicomread( magnitude.info ) );

phase.filename  = sSeries.instance( pci ).filename;
phase.info      = dicominfo( phase.filename );
phase.image     = double( dicomread( phase.info ) );

% conversion phase map from pixel values to Hz
% Philips has the RescaleSlope field defined.
if isfield( phase.info, 'RescaleSlope' ) && isfield( phase2.info, 'RescaleSlope' )
    factor  =  phase.info.RescaleSlope;
    offset  = 0; % matlab reads the offset already from RescaleIntercept
elseif isfield( phase.info, 'RealWorldValueMappingSequence' ) && ...
       isfield( phase.info.RealWorldValueMappingSequence, 'Item_1' ) && ...
       isfield( phase.info.RealWorldValueMappingSequence.Item_1, 'RealWorldValueSlope') && ...
       isfield( phase.info.RealWorldValueMappingSequence.Item_1, 'RealWorldValueIntercept')
    factor  =  phase.info.RealWorldValueMappingSequence.Item_1.RealWorldValueSlope;
    offset  =  phase.info.RealWorldValueMappingSequence.Item_1.RealWorldValueIntercept;
else
    % don't know what to do without the rescale slope...
    WAD_vbprint( [my.name ':   ERROR: phase image does not have RescaleSlope or '] );
    WAD_vbprint( [my.name ':          RealWorldValueMappingSequence.Item_1.RealWorldValueSlope + Intercept defined. Skipping analysis'] );
    error( 'Error during import of phase images.' )
end

% B0 map in Hz
phase.dB0_Hz = phase.image * factor - offset;

% convert back to phase in radians, in order to unwrap the B0 map
% only possible if delta-TE is known!
if isfield( sParams, 'deltaTE_ms' )
    phase.dTE = sParams.deltaTE_ms;
    % WAD2 passes params as strings
    if ischar(phase.dTE), phase.dTE=str2double(phase.dTE); end
    phase.dPhi_rad = phase.dB0_Hz * (2*pi) * phase.dTE * 1E-3;
    phase.type = 'dPhi_rad';
else
    % use B0 map in Hz, may contain wraps though!
    phase.type = 'dB0_Hz';
end
