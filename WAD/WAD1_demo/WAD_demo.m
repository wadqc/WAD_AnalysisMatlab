% ------------------------------------------------------------------------
% WAD_demo is a demo analysis module written for IQC.
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

% ----------------------
% Note: these folders should be in your Matlab path:
% - WAD
% - xml_io_tools
% ----------------------


function WAD_demo( wadInputFileXML )
% Main routine to be called from the WAD framework (WAD_Processor)
%
% In fact this is just a modality-specific wrapper around the standard WAD
% main routine (WAD_main.m)
%
% Provides a place for additional configs/defines/...
% ------------------------------------------------------------------------
% v1.1 20131127 updated for new (v1.1) style action limits

% ----------------------
% defines
% ----------------------
% version info
my.name = 'WAD_demo';
my.version = '1.1';
my.date = '20131127';

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
% WAD_main is located in folder WAD
% ----------------------
WAD_main( wadInputFileXML );
