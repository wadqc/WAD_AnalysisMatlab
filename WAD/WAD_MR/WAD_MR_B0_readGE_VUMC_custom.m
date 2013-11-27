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

function [magnitude, phase] = WAD_MR_B0_readGE_VUMC_custom( i_iSeries, sSeries, sParams )
% Import function for BO uniformity GE phase difference field map 
% (implemented as a VUMC custom sequence). Acquisition must be single slice.
%
% This is a import function to be called from WAD_MR_B0_uniformity()
%
% Configuration name for the <params><type> field:
% GE_VUMC_custom
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


% ----------------------
% GLOBALS
% ----------------------
%global WAD

% version info
my.name = 'WAD_MR_B0_readGE_VUMC_custom';
my.version = '1.1';
my.date = '20131127';
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

if isfield( info, 'Private_0019_109c' ) &&  strfind( info.Private_0019_109c, 'fgre_B0' )
    % custom sequence for B0 map on GE
    WAD_vbprint( [my.name ':   Detected VUmc custom B0 map for GE.'] );
else
    WAD_vbprint( [my.name ':   Could not detect Siemens VUmc custom B0 map for GE. Private_0019_109c not equal to "fgre_B0"'] );
    error( 'Error during import of phase images.' )
end

WAD_vbprint( [my.name ':   Setting type of B0 map to GE custom.'] );
% GE has (custom) B0 map in single series, magn/phase pair.
if length( sSeries.instance ) ~= 2
    WAD_vbprint( [my.name ':   ERROR: B0 map has more than one slice. Skip analysis'] );
    error( 'Error during import of phase images.' )
end

% magnitude series / image
mci = 1;
% phase series / image
pci = 2;

% ----------------------------------------------------
% read DICOM images
% ----------------------------------------------------
magnitude.filename = sSeries.instance( mci ).filename;
magnitude.info  = dicominfo( magnitude.filename );
magnitude.image = double( dicomread( magnitude.info ) );

phase.filename  = sSeries.instance( pci ).filename;
phase.info      = dicominfo( phase.filename );
phase.image     = double( dicomread( phase.info ) );

% conversion phase map from pixel values to radians
factor = 1/1000;
offset = 0;

% convert from phase image from pixel values to radians
phase.dPhi_rad = phase.image * factor - offset;

% GE custom has time between echoes as TE in DICOM header of the
% PHASE image
phase.dTE = phase.info.EchoTime;

