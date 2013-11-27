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

function WAD_demo_actionOne( i_iSeries, sSeries, sParams )
% Get some parameters from the DICOM header
% 
% Input
% - i_iSeries: the actual SeriesNumber (source: XML input file)
% - sSeries: structure with actual series information as parsed from the
%   XML input file. Check the input file what is actually in there.
% - sParams: structure with the parameter fields defined in the
%   configuration file for this action.
% - sLimits: stucture with action limits defined in the configuration file
%   for this action.
%
% Note that the full input file structure may be accessed through the
% global variable WAD.in
%
% Output: written via WAD_resultsAppend*() interface
%
% ------------------------------------------------------------------------
% WAD demo
% file: WAD_demo_actionOne
% 
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2013-09-05 / JK
% first version
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 20131127 / JK
% v1.1 implemented new style action limits
%
% To upgrade your own module to the new style:
% - remove last two arguments from your calls to WAD_resultsAppendFloat(...)
% - edit your module configuration file
% ------------------------------------------------------------------------

% version info
my.name = 'WAD_demo_actionOne';
my.version = '1.1';
my.date = '20131127';

% output to log file
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );

% ----------------------
% GLOBALS
% ----------------------
% if you defined anything in WAD_demo.m or need to use WAD.in
global WAD



% read dicom header of first image of series
WAD_vbprint( [my.name ':   Reading DICOM header: ' sSeries.instance(1).filename ] );
try
    dicomheader = dicominfo( sSeries.instance(1).filename );
catch err
    % This will go to the log file. In addition the Processor log file
    % contains the terminal output, which allows backtracing of the error.
    WAD_ErrorMsg( my.name, ['ERROR reading DICOM info from file "' sSeries.instance(1).filename '")'], err );
    return
end

% just as an example: dump complete DICOM header in Matlab format to logfile
if WAD.cfg.logverbose.fid ~= -1
    gen_object2file( WAD.cfg.logverbose.fid, dicomheader );
end

% now get something from the DICOM header and present it as result
% StationName should be defined, but check anyway...
if isfield( dicomheader, 'StationName' ) && ~isempty( dicomheader.StationName )
    
    WAD_vbprint( [my.name ': Getting StationName from header'] );
    stationName = dicomheader.StationName;

    % write string to results level 1
    % WAD_resultsAppendString( level, value, description )
    WAD_resultsAppendString( 1, stationName, 'Station Name' );
    % write some diagnostic info to results level 2
    WAD_resultsAppendString( 2, 'Station name was found in DICOM header', 'ActionOne info' );
else
    % write some diagnostic info to results level 2 and to log file
    WAD_resultsAppendString( 2, 'Station name not in DICOM header', 'ActionOne info' );

    WAD_vbprint( [my.name ': StationName not defined in DICOM header.'] );
end

return
