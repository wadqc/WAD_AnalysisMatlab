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

function [magnitude, phase] = WAD_MR_B0_readGE_B0map( i_iSeries, sSeries, sParams )
% Import function for BO uniformity GE phase difference field map 
% (GE research type-in: B0map). Acquisition must be single slice.
%
% This is a import function to be called from WAD_MR_B0_uniformity()
%
% Configuration name for the <params><type> field:
% GE_B0map
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
% 20140207 / JK
% V1.1
% - new function GE_B0map for GE research type-in: B0map
% - for GE software level HD23 or DV23 or newer
% - sequence produces a B0 map in [Hz]
% ------------------------------------------------------------------------
% 20140212 / JK
% V1.1.1
% Private fields are class uint8 and in one column for implicit DICOM, and class char and one row for explicit DICOM
% char(info.Private_2001_1020(:))' converts both to class char and one row.
% ------------------------------------------------------------------------
% 20150901 / JK
% V1.1.2
% Fix: wrong image number if received in random order.
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
%global WAD

% version info
my.name = 'WAD_MR_B0_readGE_B0map';
my.version = '1.1.2';
my.date = '20150901';
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

if isfield( info, 'Private_0019_109c' ) && strfind( char(info.Private_0019_109c(:))', 'B0map' )
    % custom sequence for B0 map on GE
    WAD_vbprint( [my.name ':   Detected research type-in B0map for GE.'] );
else
    WAD_vbprint( [my.name ':   Could not detect type-in B0map for GE. Private_0019_109c not equal to "B0map"'] );
    error( 'Error during import of phase images.' )
end

WAD_vbprint( [my.name ':   Setting type of B0 map to GE B0map.'] );
% GE has (custom) B0 map in single series, magn/phase pair.
if length( sSeries.instance ) ~= 2
    WAD_vbprint( [my.name ':   ERROR: B0 map has more than one slice. Skip analysis'] );
    error( 'Error during import of phase images.' )
end


% ---------------------------------------------
% find the image
% ---------------------------------------------
foundImage = false;
for ii = 1:length( sSeries.instance )
    if sSeries.instance(ii).number == 2
        mci = ii;
        foundImage = true;
        break;
    end
end
if ~foundImage
    WAD_vbprint( [my.name ': Error: could not find magnitude image (#2) ' num2str( inum ) ' for GE B0 map'] );
    return;
end

% find phase image
foundImage = false;
for ii = 1:length( sSeries.instance )
    if sSeries.instance(ii).number == 1
        pci = ii;
        foundImage = true;
        break;
    end
end
if ~foundImage
    WAD_vbprint( [my.name ': Error: could not find phase image (#1) ' num2str( inum ) ' for GE B0 map'] );
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
%phase.image     = double( dicomread( phase.info ) );

phase.dB0_Hz   = double( dicomread( phase.info ) ); % image is in Hz
phase.type      = 'dB0_Hz';

% NOTE: limits (phase wrap) defined in DICOM field (0019,10ab)
phase.range = str2double( char( phase.info.Private_0019_10ab(:) )' );
WAD_vbprint( [my.name ':   Info: phase wrap at +/- ' char(phase.info.Private_0019_10ab(:))' ' Hz.'] );
