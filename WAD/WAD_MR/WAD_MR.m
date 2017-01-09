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

function WAD_MR( wadInputFileXML )
% Main routine to be called from the WAD framework (WAD_Processor)
%
% In fact this is just a modality-specific wrapper around the standard WAD
% main routine (WAD_main.m)
%
% Provides a place for additional configs/defines/...
% ------------------------------------------------------------------------
% 20131127 / JK / v1.1
% Support new (v1.1) style action limits
% ------------------------------------------------------------------------
% 20140116 / JK / v1.1.1
% - Support Toshiba B0 map (iAAS)
% ------------------------------------------------------------------------
% 20161021 / JK / v1.1.2
% - Support GE multislice B0 map and multislice multichannel SNR
%
%   For multislice B0: need to configure magnitude and phase instance
%   numbers in parameter section:
% 	<name>WAD_MR_B0_uniformity</name>
% 	<match>B0_MAP</match>
% 	<params>
% 	    <type>GE_VUMC_custom</type>
%	    <imageMagnitude>7</imageMagnitude>
%	    <imagePhase>18</imagePhase>
%	</params>
%
%   For multislice multichannel SNR: need to configure combined and
%   uncombined instance numbers in parameter section:
% 	<name>WAD_MR_SNR_MultiChannel</name>
% 	<match>ACR SNR 8CH</match>
% 	<params>
% 	    <combinedImage>63</combinedImage>
% 	    <uncombinedImage> <image>55</image> <coil>1</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>56</image> <coil>2</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>57</image> <coil>3</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>58</image> <coil>4</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>59</image> <coil>5</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>60</image> <coil>6</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>61</image> <coil>7</coil> </uncombinedImage>
% 	    <uncombinedImage> <image>62</image> <coil>8</coil> </uncombinedImage>
%	</params>
%
% ------------------------------------------------------------------------


% ----------------------
% defines
% ----------------------
% version info
my.name = 'WAD_MR';
my.version = '1.1.2';
my.date = '20161021';

disp( ['Starting analysis module ' my.name '  Version ' my.version ' ' my.date] );


% ----------------------
% check input arguments
% ----------------------
if nargin < 1
    disp( ['ERROR in ' my.name ' main program: missing WAD XML input file.'] );
    disp( ['Usage: ' my.name ' <XMLInputFile>'] );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end


% ----------------------
% GLOBALS
% ----------------------
clear global WAD
global WAD


% ----------------------
% initialize modality-specific constants
% ----------------------
% combined image options
WAD.const.firstInSeries = 'firstInSeries';
WAD.const.lastInSeries  = 'lastInSeries';
WAD.const.inNextSeries  = 'inNextSeries';
% default size and shift [mm] for SNR/ghosting ROI's
WAD.const.defaultRoiRadius = 75; % [mm]
WAD.const.defaultBackgroundRoiShift = 108; % [mm]
WAD.const.defaultBackgroundRoiSize = 7; % [mm]

% ----------------------
% call main function
% ----------------------
WAD_main( wadInputFileXML );
