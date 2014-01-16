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

function [magnitude, phase] = WAD_MR_B0_readToshibaAAS( i_iSeries, sSeries, sParams )
% Import function for BO uniformity Siemens phase difference field map 
% (part of the fMRI product package). Acquisition must be single slice.
%
% This is a import function to be called from WAD_MR_B0_uniformity()
%
% Configuration name for the <params><type> field:
% SiemensPhaseDifference
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
% 20140116 / JK
% V1.1
% - read Toshiba B0 map (product shim), adapted from readSiemens...
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
global WAD

% version info
my.name = 'WAD_MR_B0_readToshibaAAS';
my.version = '1.1';
my.date = '20140116';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );

% output arguments
magnitude = [];
phase = [];

% default image number to be analysed
defaultImageNumber = 9;

% ----------------------------------------------------
% check image type, get dicom header of first file
% ----------------------------------------------------
fname = sSeries.instance( 1 ).filename;
WAD_vbprint( [my.name ':   Check type of B0 map... reading DICOM header of file ' fname ] );
info = dicominfo( fname );

% test for Toshiba B0 map produced from auto shim sequence, based on sequence name
if isfield( info, 'SequenceName' ) && strcmp( info.SequenceName, 'FE_AAS' )
    % Toshiba product shim sequence
    WAD_vbprint( [my.name ':   Detected Toshiba iAAS.'] );
else
    WAD_vbprint( [my.name ':   Could not detect Toshiba B0 mao: SequenceName not equal to "FE_AAS"'] );
    error( 'Error reading Toshiba B0 images.' )
end


WAD_vbprint( [my.name ':   Setting type of B0 map to Toshiba shim map.'] );
% Toshiba stores B0 map in two series:
% - first series has the 2 magnitude images and a phase difference image
% - second series has the B0 map in ppm
if info.AcquisitionNumber ~= 1
    WAD_vbprint( [my.name ':   ERROR: B0 map [ppm] selected. Please select series with magnitude images. Skipping analysis'] );
    error( 'Error during import of B0 map.' )
end

% -----------------------
% find the next series...
% -----------------------
foundNextSeries = false;
curStudy = WAD.in.patient(1).study(1);
i_nSeries = length( curStudy.series );
for ii = 1:i_nSeries
    if ( curStudy.series( ii ).number == sSeries.number + 1 )
        sPhsSeries = curStudy.series( ii );
        foundNextSeries = true;
        break;
    end
end
if ~foundNextSeries
    WAD_vbprint( [my.name ': ERROR: could not find next series for B0 image. Skip analysis.'] );
    error( 'Error during import of phase images.' )
end

% Get image number from configuration file...
if ~isfield( sParams, 'image' ) || isempty( sParams.image )
    % use default image number
    sParams.image = defaultImageNumber;
end

% magnitude series / image
mci = sParams.image;
% phase series / image
pci = sParams.image;

% if next series belongs to this one, it should have same name, and should
% have one thrird of number of images.
if ~strcmp( sSeries.description, sPhsSeries.description ) || length( sPhsSeries.instance ) ~= length( sSeries.instance ) ./ 3
    WAD_vbprint( [my.name ':   ERROR: B0 image is in next series, but the next series doesn''t have same series description or doesn''t have matching number of images. Skip analysis'] );
    error( 'Error during import of phase images.' )
end

% ----------------------------------------------------
% read DICOM images
% ----------------------------------------------------
magnitude.filename = sSeries.instance( mci ).filename;
magnitude.info  = dicominfo( magnitude.filename );
magnitude.image = double( dicomread( magnitude.info ) );

phase.filename  = sPhsSeries.instance( pci ).filename;
phase.info      = dicominfo( phase.filename );
phase.dB0_ppm   = double( dicomread( phase.info ) ) ./ 1000; % image is in ppm multiplied with factor 1000
phase.type      = 'dB0_ppm';
