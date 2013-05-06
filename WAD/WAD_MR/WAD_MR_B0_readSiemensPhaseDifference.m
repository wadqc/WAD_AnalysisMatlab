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

function [magnitude, phase] = WAD_MR_B0_readSiemensPhaseDifference( i_iSeries, sSeries, sParams, sLimits )
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


% ----------------------
% GLOBALS
% ----------------------
global WAD

% version info
my.name = 'WAD_MR_B0_readSiemensPhaseDifference';
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

% test for Siemens phase difference map, based on sequence name
if isfield( info, 'SequenceName' ) && strcmp( info.SequenceName, '*fm2d2' )
    % Siemens product phase difference sequence for FMRI
    WAD_vbprint( [my.name ':   Detected Siemens phase difference.'] );
else
    WAD_vbprint( [my.name ':   Could not detect Siemens phase difference: SequenceName not equal to "*fm2d2"'] );
    error( 'Error reading Siemens phase difference images.' )
end


WAD_vbprint( [my.name ':   Setting type of B0 map to Siemens phase difference.'] );
% Siemens phase map has B0 map in two series:
% - first series has the 2 magnitude images
% - second series has the phase difference image (must be skipped
% if selected!!
if length( sSeries.instance ) ~= 2
    WAD_vbprint( [my.name ':   ERROR: B0 map has more than one slice, or phase series selected. Skipping analysis'] );
    error( 'Error during import of phase images.' )
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
    WAD_vbprint( [my.name ': ERROR: could not find next series for phase image. Skip analysis.'] );
    error( 'Error during import of phase images.' )
end

% magnitude series / image
mci = 1;
% phase series / image
pci = 1;

% if next series belongs to this one, it should have same name, and just one image.
if ~strcmp( sSeries.description, sPhsSeries.description ) || length( sPhsSeries.instance ) ~= 1
    WAD_vbprint( [my.name ':   ERROR: phase image is in next series, but the next series doesn''t have same series description or doesn''t have 1 image. Skip analysis'] );
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
phase.image     = double( dicomread( phase.info ) );

% conversion phase map from pixel values to radians
factor = 2*pi/4096;
offset = pi;

% convert from phase image from pixel values to radians
phase.dPhi_rad = phase.image * factor - offset;

% Siemens doesn't store the delta TE in the DICOM header but it's
% fixed in the product sequence
phase.dTE = 4.76;
